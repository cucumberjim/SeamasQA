> **NOTE**: This project should be treated as a training exercise.
Do not write actual code just the project skeleton (with an explanatory
Markdown file) and unit/integration tests allowing TDD development by me.
After that, I'll write code and have Claude mentor and check me.

* Create a drop-in git hook file for use with this plugin
  * Should call Claude Code requesting a "code review" and exit automatically
    returning non-zero and the session ID to reconnect to the session to
    discuss the review.
  * Code review conversation to store results into a file such that the
    subsequent review when committing passes if a different solution/proposal
    was arrived at in the conversation.
  * hook has an optional sink with an environment variable to a script to 
    run custom tests.
  * Hook to detect if the commit is being run from one of the following
    and run checks based on that.  An skip environment variable for each
    should be respected, but should still raise warnings not failing the
    commit:
    * Chef cookbook or policyfile - run `cookstyle .` and `chef exec rspec`
    * If there are "*.json" files in the git managed files, confirm
      valid JSON.
    * If there are "*.yml" files in the git managed files, confirm
      valid yml.
    * If there are "*.ps1" files in the git managed files, confirm
      Powershell linting passes.  If `pwsh` not present, fail.
    * If there are "*.sh" files in the git managed files, confirm
      shell (bash) linting passes.
        * On Windows, attempt to create a WSL Rocky instance for bash
          tests and fail if WSL not present or unable to create an ephemeral
          instance.  Create a terse doc in this repo on installing WSL2 and
          echo content to screen if WSL2 not present/enabled.
    * If there are "*.py" files in the git managed files, confirm
      Python3 linting passes.
        * On Windows, attempt to create a WSL Rocky instance for Python3
          tests and fail if WSL not present or unable to create an ephemeral
          instance.  Create a terse doc in this repo on installing WSL2 and
          echo content to screen if WSL2 not present/enabled.
* Create or find a Claude Code skill for doing a "code review"
  * Should be able to set strictness via environment variable
    similar to Ponytail plug-in but getting into `nit`s or not and constraining
    token load.
  * Always do a strict security check for input validation and other
    OWASP secure coding principals.
  * Accept an optional "configuration" file in a standard location to note
    natural language and internal conventions that don't have a strict
    linter.  Treat these as nit level concerns.
  * Pre-can logic to optimize token use for these languages:
    * Ruby
    * Chef DSL
    * Powershell (both Windows and regular)
    * Python
    * shell/bash
    * Windows cmd shell
    * C#
    * Javascript / Node.js
  * "build" script for skill should regenerate these using an appropriate prompt,
    optionally commit.
* Wrapping script to install the git hook and built Claude Code skill from
  cloned repo.
* Recommendations for this skill from Claude
