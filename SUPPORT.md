# Support

**There is no support on offer, and none is being sold.** StateUI is written by
one person, in the open, and given away. At this stage of the project that is
the whole answer.

## What there is instead

- **The documentation.** The [handbook](docs/README.md) carries the model, the
  architecture and the reason behind most of the decisions that look odd from
  outside, and the public API documentation sits beside every declaration.
  Search it first - the answer is often already there.
- **The issue tracker, as a place to leave a report.** A bug with a
  reproduction is useful to the project whether or not anybody replies to it,
  and a proposal there is how a change to the API starts - see
  [CONTRIBUTING.md](CONTRIBUTING.md).

## What you cannot expect

- **A reply.** Issues are read when there is time to read them. Many get an
  answer; none is promised one.
- **A response time.** There is none, and nothing here implies one.
- **Help with your own application's code.** Questions about StateUI's own
  behaviour are the interesting kind; an application's own design is its
  author's to answer.
- **A stable API.** This is version 0.3 and the shape of things is still being
  found, so **using StateUI in a project is at your own risk**: names and
  signatures move between versions, and there is no deprecation cycle yet to
  soften it.
- **Backports, or a fix on your schedule.** A fix lands when it lands.
- **Paid support.** It is not offered at this stage - not as an upsell, and not
  quietly on request.
- **A guarantee of anything.** The [Apache License 2.0](LICENSE) says this in
  capital letters and means it: the software is provided on an "AS IS" basis,
  with no warranty or condition of any kind.

## Whether this stays true

This describes the project as it is now, not a policy meant to outlast it. What
changes depends on how much interest the project attracts and how far it goes;
if it changes, this file changes with it. Until then, what is above is what to
assume.

## Making a report easy to act on

Most of the traps in this project are platform-specific, so a report that names
the platform is worth several that do not:

- what you did, what happened, and what you expected instead
- the platform and its version - macOS, iOS, Android, Windows or Linux
- the StateUI version, and the Swift toolchain's
- the smallest piece of code that shows it

A stack trace or the exact error text beats a description of it.

## Security

Please do not open a public issue for a vulnerability. [SECURITY.md](SECURITY.md)
says where it goes instead - GitHub's own private advisory form - and what
happens after.
