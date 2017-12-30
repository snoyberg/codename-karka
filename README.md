# codename-karka

This is a repo to track plans and work on a whole bunch of
tangentially-related projects and initiatives, mostly around
refactoring libraries. The ultimate goal for all of this can be
summarized easily as:

> Make it easier to adopt Haskell for writing production software

This document was originally written by Michael Snoyman, and has a
bias towards my libraries. Hopefully others contribute their ideas
too.

__Naming__ We already have `yesod`, which means foundation in
Hebrew. And we have `foundation`, which means... foundation. Karka
(קרקע) is the Hebrew word for "ground." This is the ground on which to
build awesome Haskell stuff. This is just a name to be used when
discussing the project initially, no library is intended to use this
name.

## High level goals

The primary objective here is to __create a useful standard
library__. The problem is that the base library in Haskell gets many
things wrong (e.g., partial functions, `String`) and does not contain
a lot of functionality we need (e.g., `HashMap`). As a result, real
world Haskell code needs to use helper libraries. However:

* It's often unclear which is the right library to use
* People are afraid of adding dependencies to their projects
* Other packages use incompatible types

One approach would be to try to get the changes made to `base`
itself. That's overly ambitious:

* It's all but impossible to get general consensus on the right set of
  changes
* `base` is difficult to modify since it's tied to GHC itself
* It's difficult to iterate quickly on `base` since it can't be
  upgraded
* We want to make it easy for users to start using this library
  without changing GHC versions

Another approach is to write an alternative to the commonly used
libraries out there. `foundation` takes this approach. This has the
downside of making it difficult to interoperate with existing
libraries. This proposal instead takes an evolutionary approach: use
the existing libraries.

__Goals__:

* Provide a single library for users to import which provides common
  functionality (discussed below)
* Documentation that describes best practices for common topics (also
  discussed below)
* Make the dependencies lightweight enough that it can be considered a
  reasonable import for most use cases
* Have a sensible dependency tree: depend on the right set of
  libraries, but nothing more
* Maximize compatibility with commonly used libraries already out
  there (e.g., warp, lens)
* Easy to get started for a new project
* Sensible prelude

__Non-goals__:

* Universal adoption. This will be an opinionated library. We want to
  get buy-in from an active group of developers, but there will be
  legitimate reasons some people don't want to use this. That's fine.
* Improve the core libraries we depend on. Such improvements may take
  place in the future, but for now our goal is to be downstream
  consumers of existing well used functionality.

__Up for debate__:

* Do we encourage people to use qualified imports, e.g. `import
  qualified RIO.ByteString as B`, or do we provide a polymorphic
  prelude using a library like `mono-traversable`?
    * Michael's initial thought: as much as I like `mono-traversable`,
      most best practices today go for the qualified import route. I'm
      willing to bend on this one, but I'd like to provide helper
      modules that reexport the `ByteString` and other APIs to avoid
      needing to litter `build-depends` with lots of dependencies, and
      to make it easy for us to augment the APIs if needed.

## Desired functionality

__Definitely in__

* Everything already covered by the `unliftio` package
  https://www.stackage.org/package/unliftio
* Data structures: `ByteString`, `Text`, `Vector` (all three
  variants), `Map`, `HashMap`, `Set`, `HashSet`
* A `RIO` monad https://github.com/fpco/unliftio/issues/6
* Logging (include a replacement for `monad-logger`)
* Running and interacting with external processes

__Maybe in__

* streaming
* network
* lenses
* HTTP requests (probably not due to dependency footprint
* Testing
* cryptography
* Random number generation
* A better output generation approach (e.g., `class Display a where display :: a -> Builder`, and `say :: Builder -> IO ()`)

__Definitely out__

* Web framework

## Best practices

* [RIO](https://www.fpcomplete.com/blog/2017/07/the-rio-monad)
* [Exceptions](https://www.fpcomplete.com/blog/2016/11/exceptions-best-practices-haskell)
* Don't use partial functions
* Don't use lazy I/O
* The right set of effect typeclasses: `MonadReader`, `MonadIO`,
  `MonadUnliftIO`, `MonadThrow`, and `PrimMonad`. There's some room
  for debate on this, and whether it's necessary if we're promoting
  `RIO`. But what I'd like to avoid is promoting `MonadBase`,
  `MonadBaseControl`, `MonadCatch`, and `MonadMask`.

## Technical approach

1. Define the set of libraries which we're considering acceptable
   dependencies. Initial list:

    * base
    * bytestring
    * text
    * primitive
    * vector
    * transformers
    * mtl
    * stm
    * containers
    * unordered-containers
    * async
    * deepseq
    * directory
    * filepath
    * unliftio-core
    * unliftio
    * unix and Win32 (per platform basis)
    * time
    * typed-process
    * exceptions (needed only for the `MonadThrow` typeclass, up for serious debate)

2. Define a set of GHC versions to support. Proposal: only GHC 8.0.2
   and 8.2.2 to start.

3. Extract code from Stack, in line with the proposal https://github.com/commercialhaskell/stack/issues/3620.

4. For any functionality which is naturally namespaced
   (e.g. `newIORef`), expose from the main module itself (assumed
   name: `RIO`). For functionality intended to be imported qualified,
   even if it's from an underlying library, provide a module
   (e.g. `RIO.ByteString`), and document a recommended qualified name
   import (e.g., `import qualified RIO.ByteString as B`)

5. Write a `README` explaining that this package will get you started
   quickly with Haskell, how to use it, tooling to use (like Stack),
   how to start a new project, and pointers to learning material and
   other libraries to consider using.

## Refactor Michael's existing libraries to match

This is a separate, parallel effort that Michael is undertaking. The
original impetus is the fact that many of my libraries make extensive
use of `lifted-base`, which I want to stop encouraging due to safety
issues. I've started to rewrite some major libraries (conduit, yesod,
and related packages) to move over entirely to `unliftio-core`
instead. In that process, I'll try to make these libraries compatible
with the goals of this initiative, and perhaps in the future some of
those libraries (conduit and resourcet in particular) may be exposed
here.

Relevant links:

* https://github.com/snoyberg/conduit/issues/283
* https://github.com/snoyberg/conduit/pull/338
* https://github.com/yesodweb/yesod/pull/1463
* https://github.com/yesodweb/yesod/pull/1464
* https://github.com/yesodweb/yesod/pull/1466
* https://gist.github.com/snoyberg/50864f697234ff15a6c6fd0aeb183a0b
* https://github.com/fpco/unliftio/issues/6
