// node --test Scripts/changelog/acknowledgements.test.mjs   (or: npm test --prefix Scripts/changelog)
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { acknowledgements, closedIssues, description } from './acknowledgements.mjs'

const user = login => ({ login, __typename: 'User' })
const issue = (number, login, authorAssociation = 'NONE', title = `Issue ${number}`) =>
  ({ number, title, author: user(login), authorAssociation })
const pull = (number, login, authorAssociation, closing = [], title = `fix: change ${number}`) =>
  ({ number, title, author: user(login), authorAssociation, closing })
const commit = (subject, { author = null, pulls = [], coAuthors = [], body = '' } = {}) =>
  ({ subject, message: body ? `${subject}\n\n${body}` : subject, author, pulls, coAuthors })

test('closing keywords', () => {
  assert.deepEqual(closedIssues('fix: x\n\nFixes #12, closes #13 and Resolved #14. See #15.'), [12, 13, 14])
  assert.deepEqual(closedIssues('Fix: #7'), [7])
  assert.deepEqual(closedIssues('prefix#3 fixes#4'), [])
})

test('description drops type and scope', () => {
  assert.equal(description('fix(panel): keep focus'), 'keep focus')
  assert.equal(description('feat!: new vault format'), 'new vault format')
})

test('nobody to thank gives no section', () => {
  assert.deepEqual(acknowledgements([commit('fix: a', { author: 'gary' })], {}), [])
})

test('outside contributors and the reporters of the issues they close', () => {
  const lines = acknowledgements([
    commit('fix: furigana', { author: 'alice', pulls: [pull(209, 'alice', 'CONTRIBUTOR', [issue(206, 'bob')], 'fix(lyrics): fix automatic furigana')] })
  ], {})
  assert.deepEqual(lines, [
    '## Acknowledgements', '',
    '* @alice (#209) fix automatic furigana.',
    '* @bob reported #206: Issue 206'
  ])
})

test('maintainers and bots are left out', () => {
  const lines = acknowledgements([
    commit('fix: a', { author: 'gary' }), // pushed directly: a maintainer
    commit('fix: b', { pulls: [pull(1, 'gary', 'OWNER', [issue(5, 'gary', 'OWNER')])] }),
    commit('fix: c', { pulls: [pull(2, 'carol', 'MEMBER')] }),
    commit('chore: d', { pulls: [{ ...pull(3, 'renovate', 'NONE'), author: { login: 'renovate', __typename: 'Bot' } }] }),
    commit('fix: e', { pulls: [pull(4, 'dependabot[bot]', 'NONE')] })
  ], {})
  assert.deepEqual(lines, [])
})

test('a report closed by a direct commit message is credited', () => {
  const lines = acknowledgements(
    [commit('fix(panel): keep focus', { author: 'gary', body: 'Fixes #206' })],
    { 206: issue(206, 'bob', 'NONE', 'Panel loses focus ') }
  )
  assert.deepEqual(lines, ['## Acknowledgements', '', '* @bob reported #206: Panel loses focus'])
})

test('a maintainer who also commits directly is not thanked for their own report', () => {
  const lines = acknowledgements(
    [commit('fix: a', { author: 'gary', body: 'Closes #8' })],
    { 8: issue(8, 'gary', 'NONE') } // association can be NONE for an org repo's owner account
  )
  assert.deepEqual(lines, [])
})

test('someone who fixed their own report is thanked once', () => {
  const lines = acknowledgements([
    commit('fix: a', { pulls: [pull(30, 'dana', 'FIRST_TIME_CONTRIBUTOR', [issue(29, 'dana')])] })
  ], {})
  assert.deepEqual(lines, ['## Acknowledgements', '', '* @dana (#30) change 30.'])
})

test('co-authors, and each contribution and report only once', () => {
  const report = issue(40, 'erin')
  const lines = acknowledgements([
    commit('feat: pairing', { author: 'gary', coAuthors: ['frank'] }),
    commit('fix: one', { pulls: [pull(41, 'alice', 'CONTRIBUTOR', [report])], body: 'Fixes #40' }),
    commit('fix: two', { pulls: [pull(41, 'alice', 'CONTRIBUTOR', [report])] })
  ], { 40: report })
  assert.deepEqual(lines, [
    '## Acknowledgements', '',
    '* @frank pairing.',
    '* @alice (#41) change 41.',
    '* @erin reported #40: Issue 40'
  ])
})

test('fetching maps GitHub data, and failures leave the section out', async () => {
  const { fetchAcknowledgements } = await import('./acknowledgements.mjs')
  const realFetch = globalThis.fetch
  const realToken = process.env.GITHUB_TOKEN
  let query = ''
  process.env.GITHUB_TOKEN = 'test-token'
  globalThis.fetch = async (_url, request) => {
    query = JSON.parse(request.body).query
    return new Response(JSON.stringify({ data: { repository: {
      c0: {
        author: { user: { login: 'alice' } },
        authors: { nodes: [{ user: { login: 'alice' } }, { user: { login: 'frank' } }, { user: null }] },
        associatedPullRequests: { nodes: [
          { number: 209, title: 'fix: furigana', mergedAt: '2026-11-01T00:00:00Z', authorAssociation: 'CONTRIBUTOR',
            author: user('alice'), closingIssuesReferences: { nodes: [issue(206, 'bob')] } },
          { number: 210, title: 'unmerged', mergedAt: null, authorAssociation: 'NONE', author: user('zed'),
            closingIssuesReferences: { nodes: [] } }
        ] }
      },
      i300: { __typename: 'Issue', ...issue(300, 'erin') },
      i301: { __typename: 'PullRequest' }
    } } }), { status: 200 })
  }
  try {
    const lines = await fetchAcknowledgements('outerstudio', 'trayotp',
      [{ hash: 'abc123', subject: 'fix: furigana', message: 'fix: furigana\n\nFixes #300, fixes #301' }])
    assert.match(query, /repository\(owner: "outerstudio", name: "trayotp"\)/)
    assert.match(query, /c0: object\(oid: "abc123"\)/)
    assert.match(query, /i300: issueOrPullRequest\(number: 300\)/)
    assert.deepEqual(lines, [
      '## Acknowledgements', '',
      '* @alice (#209) furigana.',
      '* @frank (#209) furigana.',
      '* @bob reported #206: Issue 206',
      '* @erin reported #300: Issue 300'
    ])

    globalThis.fetch = async () => new Response('{"message":"Bad credentials"}', { status: 401 })
    assert.deepEqual(await fetchAcknowledgements('o', 'r', [{ hash: 'a', subject: 'fix: a', message: 'fix: a' }]), [])
    delete process.env.GITHUB_TOKEN
    assert.deepEqual(await fetchAcknowledgements('o', 'r', [{ hash: 'a', subject: 'fix: a', message: 'fix: a' }]), [])
  } finally {
    globalThis.fetch = realFetch
    if (realToken === undefined) delete process.env.GITHUB_TOKEN; else process.env.GITHUB_TOKEN = realToken
  }
})
