#!/usr/bin/env node
// Release notes and CHANGELOG.md from Conventional Commits, with conventional-changelog.
//
//   node Scripts/changelog/changelog.mjs notes v1.2.0   # notes for one tag (the GitHub release body)
//   node Scripts/changelog/changelog.mjs file           # rewrites CHANGELOG.md
//
// Only what users notice is listed: feat, fix, perf and revert. docs, ci, build, chore, refactor,
// style and test commits are left out (the conventionalcommits preset hides them).
//
// A stable release covers everything since the previous stable release, betas included, so users
// on the stable channel see the whole update. A pre-release covers what changed since the tag before it.
// Install first: npm ci --prefix Scripts/changelog
import { execFileSync } from 'node:child_process'
import { writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { ConventionalChangelog } from 'conventional-changelog'

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, '..', '..')
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim()

/** vX.Y.Z or vX.Y.Z-pre.release, as the release workflow accepts them. */
function parse (tag) {
  const m = /^v(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$/.exec(tag)
  return m && { tag, parts: m.slice(1, 4).map(Number), pre: m[4] ? m[4].split('.') : [] }
}

/** Semantic-versioning order, like AppVersion in the app. */
function compare (a, b) {
  for (let i = 0; i < 3; i++) if (a.parts[i] !== b.parts[i]) return a.parts[i] - b.parts[i]
  if (!a.pre.length !== !b.pre.length) return a.pre.length ? -1 : 1
  for (let i = 0; i < Math.min(a.pre.length, b.pre.length); i++) {
    const [x, y] = [a.pre[i], b.pre[i]]
    if (x === y) continue
    const [m, n] = [/^\d+$/.test(x), /^\d+$/.test(y)]
    if (m && n) return Number(x) - Number(y)
    if (m !== n) return m ? -1 : 1
    return x < y ? -1 : 1
  }
  return a.pre.length - b.pre.length
}

const tags = git('tag', '--list', 'v*').split('\n').map(parse).filter(Boolean).sort(compare)

/** The tag a release's notes start from: the previous stable one for a release, else the previous one. */
function previous (version) {
  const older = tags.filter(t => compare(t, version) < 0 && (version.pre.length || !t.pre.length))
  return older.at(-1)
}

/** One release section, all commits between the two tags (the first release: since the first commit). */
async function section (version) {
  const from = previous(version)
  const generator = new ConventionalChangelog(root)
    .readPackage(join(here, 'package.json'))
    .loadPreset('conventionalcommits')
    .commits({ from: from?.tag, to: version.tag })
    .context({
      version: version.tag.slice(1),
      previousTag: from?.tag ?? git('rev-list', '--max-parents=0', 'HEAD').split('\n')[0],
      currentTag: version.tag,
      date: git('log', '-1', '--format=%cs', version.tag)
    })
    // One section for the whole range, not one per tag inside it (the betas before a release).
    // doFlush: write it even for the newest tag, which the library otherwise skips as already released.
    .writer({ generateOn: () => false, doFlush: true })
  let text = ''
  for await (const chunk of generator.write()) text += chunk
  return text.trim()
}

const [command, tag] = process.argv.slice(2)
if (command === 'notes' && parse(tag ?? '')) {
  const version = tags.find(t => t.tag === tag)
  if (!version) throw new Error(`No tag ${tag}`)
  // The release already has a title; drop the "## [1.2.0](…) (date)" heading.
  const body = (await section(version)).replace(/^##? .*\n+/, '').trim()
  const from = previous(version)
  const compare = from
    ? `\n\n**Full Changelog**: https://github.com/outerstudio/trayotp/compare/${from.tag}...${version.tag}`
    : ''
  process.stdout.write((body || 'No user-facing changes.') + compare + '\n')
} else if (command === 'file') {
  const stable = tags.filter(t => !t.pre.length).reverse()
  const sections = []
  for (const version of stable) sections.push(await section(version))
  writeFileSync(join(root, 'CHANGELOG.md'),
    '# Changelog\n\nUser-facing changes in each release. Pre-releases are listed on the ' +
    '[Releases](https://github.com/outerstudio/trayotp/releases) page.\n\n' + sections.join('\n\n') + '\n')
  console.log(`Wrote CHANGELOG.md (${stable.length} releases)`)
} else {
  console.error('Usage: changelog.mjs notes vX.Y.Z | file')
  process.exit(2)
}
