// The "Acknowledgements" section of the release notes: people outside the project whose pull
// requests are in the release, co-authors, and the people who reported the issues it closes.
//
// Data comes from GitHub's GraphQL API (a token is needed: GITHUB_TOKEN or GH_TOKEN). Issues
// count as closed when a pull request closes them (`Fixes #12` in its description, or linked in
// its sidebar) or when a commit message says so (`Fixes #12`, `Closes #12`, `Resolves #12`).
// Maintainers (anyone with push access, or who pushed a commit directly) and bots are left out.

const MAINTAINER_ASSOCIATIONS = new Set(['OWNER', 'MEMBER', 'COLLABORATOR'])

/** Issue numbers a message closes with GitHub's keywords, e.g. "Fixes #12, closes #13". */
export function closedIssues (message) {
  const numbers = []
  for (const [, n] of message.matchAll(/\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s*:?\s+#(\d+)\b/gi)) {
    numbers.push(Number(n))
  }
  return numbers
}

/** The change a commit describes, without its type and scope: "fix(panel): keep focus" → "keep focus". */
export function description (subject) {
  return subject.replace(/^\w+(?:\([^)]*\))?!?:\s*/, '')
}

const isBot = actor => !actor || actor.__typename === 'Bot' || actor.login.endsWith('[bot]')

/**
 * Builds the section from fetched data. Pure, so it can be tested without GitHub.
 * @param commits [{ subject, message, author: login|null, coAuthors: [login], pulls: [{ number, title,
 *   author: { login, __typename }, authorAssociation, closing: [issue] }] }]
 * @param issues  { [number]: { number, title, author: { login, __typename }, authorAssociation } }
 *   for the issues commit messages close (pull requests among them are ignored)
 * @returns Markdown lines, or [] when there is nobody to thank
 */
export function acknowledgements (commits, issues) {
  // Who maintains the project: associations GitHub reports, and authors of commits pushed directly.
  const maintainers = new Set()
  for (const c of commits) {
    if (!c.pulls.length && c.author) maintainers.add(c.author)
    for (const p of c.pulls) {
      if (p.author && MAINTAINER_ASSOCIATIONS.has(p.authorAssociation)) maintainers.add(p.author.login)
      for (const i of p.closing) {
        if (i.author && MAINTAINER_ASSOCIATIONS.has(i.authorAssociation)) maintainers.add(i.author.login)
      }
    }
  }
  for (const i of Object.values(issues)) {
    if (i.author && MAINTAINER_ASSOCIATIONS.has(i.authorAssociation)) maintainers.add(i.author.login)
  }
  const outside = actor => !isBot(actor) && !maintainers.has(actor.login)

  const lines = []
  const seen = new Set()
  const add = (key, line) => { if (!seen.has(key)) { seen.add(key); lines.push(line) } }
  const fixers = new Map() // issue number → logins already credited for fixing it

  for (const c of commits) {
    for (const p of c.pulls) {
      const people = [p.author, ...c.coAuthors.map(login => ({ login }))].filter(a => a && outside(a))
      for (const a of people) {
        add(`pr:${p.number}:${a.login}`, `* @${a.login} (#${p.number}) ${description(p.title)}.`)
        for (const i of p.closing) fixers.set(i.number, [...(fixers.get(i.number) ?? []), a.login])
      }
    }
    // Co-authors of a commit pushed directly, without a pull request.
    if (!c.pulls.length) {
      for (const login of c.coAuthors) {
        if (outside({ login })) add(`commit:${c.subject}:${login}`, `* @${login} ${description(c.subject)}.`)
      }
    }
  }

  const reported = new Map()
  for (const c of commits) {
    for (const p of c.pulls) for (const i of p.closing) reported.set(i.number, i)
    for (const n of closedIssues(c.message)) if (issues[n]) reported.set(n, issues[n])
  }
  for (const i of [...reported.values()].sort((a, b) => a.number - b.number)) {
    // Someone who fixed their own report is already thanked for the fix.
    if (!i.author || !outside(i.author) || fixers.get(i.number)?.includes(i.author.login)) continue
    add(`issue:${i.number}`, `* @${i.author.login} reported #${i.number}: ${i.title.trim()}`)
  }

  return lines.length ? ['## Acknowledgements', '', ...lines] : []
}

const ISSUE_FIELDS = 'number title authorAssociation author { login __typename }'

async function graphql (token, query) {
  const response = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'User-Agent': 'TrayOTP-changelog' },
    body: JSON.stringify({ query })
  })
  const json = await response.json()
  if (!response.ok || json.errors) throw new Error(JSON.stringify(json.errors ?? json))
  return json.data.repository
}

/**
 * Fetches what `acknowledgements` needs for these commits ([{ hash, subject, message }]) and
 * builds the section. Returns [] without a token, or (with a warning) if GitHub can't be reached:
 * the release still goes out, just without thanks.
 */
export async function fetchAcknowledgements (owner, name, commits) {
  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN
  if (!token || !commits.length) {
    if (!token) console.error('No GITHUB_TOKEN: leaving out acknowledgements.')
    return []
  }
  try {
    const repo = `repository(owner: ${JSON.stringify(owner)}, name: ${JSON.stringify(name)})`
    const commitFields = commits.map((c, i) => `c${i}: object(oid: "${c.hash}") { ... on Commit {
      author { user { login } }
      authors(first: 10) { nodes { user { login } } }
      associatedPullRequests(first: 5) { nodes {
        number title mergedAt authorAssociation author { login __typename }
        closingIssuesReferences(first: 10) { nodes { ${ISSUE_FIELDS} } }
      } }
    } }`)
    const numbers = [...new Set(commits.flatMap(c => closedIssues(c.message)))]
    const issueFields = numbers.map(n => `i${n}: issueOrPullRequest(number: ${n}) { __typename ... on Issue { ${ISSUE_FIELDS} } }`)
    const data = await graphql(token, `{ ${repo} { ${[...commitFields, ...issueFields].join('\n')} } }`)

    const fetched = commits.map((c, i) => {
      const node = data[`c${i}`] ?? {}
      const author = node.author?.user?.login ?? null
      return {
        subject: c.subject,
        message: c.message,
        author,
        coAuthors: (node.authors?.nodes ?? []).map(a => a.user?.login).filter(l => l && l !== author),
        pulls: (node.associatedPullRequests?.nodes ?? []).filter(p => p.mergedAt).map(p => ({
          number: p.number,
          title: p.title,
          author: p.author,
          authorAssociation: p.authorAssociation,
          closing: p.closingIssuesReferences?.nodes ?? []
        }))
      }
    })
    const issues = {}
    for (const n of numbers) if (data[`i${n}`]?.__typename === 'Issue') issues[n] = data[`i${n}`]
    return acknowledgements(fetched, issues)
  } catch (error) {
    console.error(`Could not fetch acknowledgements from GitHub: ${error.message}`)
    return []
  }
}
