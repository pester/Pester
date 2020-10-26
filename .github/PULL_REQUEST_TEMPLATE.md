<!--

Thank you for contributing to Pester! 

-->

## PR Summary

<!--

Please describe what your pull request fixes, or how it improves Pester.

If your pull request resolves a reported issue, please mention it by using `Fix #<issue_number>` on a new line, this will close the linked issue automatically when this PR is merged. For more info see: [Closing issues using keywords](https://help.github.com/articles/closing-issues-using-keywords/).

If your pull request integrates Pester with another system, please tell us how the change can be tested.

-->

## PR Checklist

- [ ] PR has meaning title
- [ ] Summary describes changes
- [ ] PR is ready to be merge
  - If not, use the arrow next to `Create Pull Request` to mark it as a draft. PR can be marked `Ready for review` when it's ready.
- [ ] All tests pass
    - Run `./build.ps1 -Clean; ./test.ps1 -NoBuild`. Use  a new PowerShell process when C# code is changed.
- [ ] Tests are added/update *(if required)*
- [ ] Documentation is updated/added *(if required)*

<!--

Before you continue, please review [Contributing to Pester](https://pester.dev/docs/contributing/introduction).

Our continuous integration system doesn't send any notifications about failed tests. Please return to the opened pull request (after ~60 minutes) to check if is everything OK.

-->