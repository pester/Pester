## Giving Back to Pester

To propose a new feature to Pester or report a bug, we encourage you to first share your findings with us by creating a new issue.  The feature or bug will be discussed, and if it's something we would like (or even love!) to see in our codebase we will ask you to create a pull request (PR) for it. We have a (more or less) standardized process for accepting PRs, but don't let that scare you away. We understand that you spent your free time to contribute, so we will take our time to help you successfully add your code to Pester.

## Getting in touch

### Reporting a bug

To report a bug, please create a new issue, and fill out the details. Your bug report should include the description of what is wrong, the version of Pester, PowerShell and the operating system. To make your bug report perfect you should also include a simple way to reproduce the bug.

Here is a piece of code that collects the required system information for you and puts it in your clipboard:

```powershell
$bugReport = &{
    $p = get-module pester
    "Pester version     : " + $p.Version + " " + $p.Path
    "PowerShell version : " + $PSVersionTable.PSVersion
    "OS version         : " + [System.Environment]::OSVersion.VersionString
}
$bugReport
$bugReport | clip
```

Example output:

```cmd
Pester version     : 3.4.4 C:\Users\nohwnd\Documents\GitHub\Pester_main\Pester.psm1
PowerShell version : 5.1.14393.206
OS version         : Microsoft Windows NT 10.0.14393.0
```

The best way to report the reproduction steps is in a form of a Pester test. But it's not always easy to do, especially if you are reporting a bug in some internal part of the framework. So feel free to provide just a list of steps that need to be taken to reproduce the bug.

### Proposing a New Feature

To propose a new feature, please create a new issue and share as much information as you see fit. Especially what the proposed feature is, why it is useful, and what dependencies (if any) it has. It would also be great if you added one or two examples of real world usage, if you have any.

When we discuss new features we look at how useful it is to the majority of users, how difficult it would be to implement, if breaking changes to the API must be introduced to have it, and if it's too specialized or too general to put in the codebase. But again, don't let that scare you away.

### Picking up issue marked as help wanted

Some of the issues are marked as [help wanted](https://github.com/pester/Pester/labels/help%20wanted). Those issues are looking for contributors to research them or implement them. When you decided to implement the issue, please comment in the issue thread so others don't waste time implementing the same thing as you.

### Got anything else to say

You don't have to report a bug or propose a feature to contact us. You can ask any Pester related questions by creating a new issue, or contacting us on [PowerShell Slack #testing channel](https://powershell.slack.com/messages/C03QKTUCS/). There is also a whole range of solved issues, that might answer your question right away, the best way to find information is through the "This repository" search field on the top of any GitHub page. On the search result page you can switch (on the left) between Code, Issues and Wikis. (Pull requests are just a sub-type of an issue.)

## Implementing a PR

So now we talked about your proposed change in the issue and it's time for you to implement the change and make it into a pull request (PR).

### Step 1 - Forking the Main Repository

You cannot add code directly to our repository, you need to first get your own copy "a fork". GitHub makes this really simple, all you need to do is log in with your GitHub account, navigate to [Pester repository](https://github.com/pester/Pester) and click the "Fork" button on the upper right. There is a helpful wizard to walk you through the process of forking and cloning the repository. At the end you should have a local copy of Pester on your computer.

If you don't have much experience with git, I suggest you download the [GitHub desktop client](https://desktop.github.com/) that will make reviewing your changes really simple. I will be describing all the steps in commands that you need to put in command line. You can get to it by clicking the cog wheel in the application and selecting "Open in Git shell".

### Step 2 - Syncing Your Clone with the Main Repository

__If you just forked and cloned as described in the Step 1 you can skip directly to step 3. Your code is already up-to-date.__

Otherwise you should make sure that your fork and your local copy (clone) is up to date. We will be updating the master branch, because that is where you should always start when creating a new PR.

First you need to tell your repository where to find the official Pester repository by setting an upstream remote, you can find how to do that [in this official guide.](https://help.github.com/articles/configuring-a-remote-for-a-fork/)

Then you need to get the latest code from the main Pester repository (upstream) and merge it to your repository, [here is another official guide on how to do that.](https://help.github.com/articles/syncing-a-fork/). Finally you push the changes to your fork on the server (origin), by running `git push` in the command line. You should repeat these steps every time you are starting a new PR, to make sure your code is up-to-date.

Here is the whole process from cloning the repository from an out-dated fork, till pushing the changes to the server:

```powershell
# cloning my fork of Pester from the server,
# (notice the /nohwnd/pester.git in the URL, unlike /pester/pester.git of the official repository)
C:\Users\nohwnd\Documents\GitHub> git clone https://github.com/nohwnd/pester.git
Cloning into 'Pester'...
remote: Counting objects: 4858, done.
remote: Total 4858 (delta 0), reused 0 (delta 0), pack-reused 4858R
Receiving objects: 100% (4858/4858), 9.14 MiB | 1.58 MiB/s, done.
Resolving deltas: 100% (3236/3236), done.
Checking connectivity... done.

# navigating to the repository folder
C:\Users\nohwnd\Documents\GitHub> cd .\Pester\

# listing the remotes to see what is there
# (notice that the URL is the same as the cloning URL and that it's called origin)
C:\Users\nohwnd\Documents\GitHub\Pester [master ≡]> git remote -v
origin  https://github.com/nohwnd/Pester.git (fetch)
origin  https://github.com/nohwnd/Pester.git (push)

# adding one more remote to tell git where the official Pester repository is
# (notice this one is called upstream, and has /pester/pester.git in the URL, unlike the fork)
C:\Users\nohwnd\Documents\GitHub\Pester [master ≡]> git remote add upstream https://github.com/pester/Pester.git

# listing the remotes again to confirm the configuration is correct
C:\Users\nohwnd\Documents\GitHub\Pester [master ≡]> git remote -v
origin  https://github.com/nohwnd/Pester.git (fetch)
origin  https://github.com/nohwnd/Pester.git (push)
upstream        https://github.com/pester/Pester.git (fetch)
upstream        https://github.com/pester/Pester.git (push)

### --- The previous steps are one-time. You can start from here on successive updates. ---

# downloading (fetching) data from the official repository
# (you can see there are some new branches and tags)
C:\Users\nohwnd\Documents\GitHub\Pester [master ≡]> git fetch upstream
remote: Counting objects: 40, done.
remote: Compressing objects: 100% (20/20), done.
remote: Total 40 (delta 23), reused 15 (delta 15), pack-reused 5
Unpacking objects: 100% (40/40), done.
From https://github.com/pester/Pester
 * [new branch]      DevelopmentV4 -> upstream/DevelopmentV4
 * [new branch]      RunOnNanoServer -> upstream/RunOnNanoServer
 * [new branch]      master     -> upstream/master
 * [new tag]         3.3.12     -> 3.3.12
 * [new tag]         3.3.13     -> 3.3.13
 * [new tag]         3.3.14     -> 3.3.14
 * [new tag]         3.4.0      -> 3.4.0
 * [new tag]         3.4.1      -> 3.4.1
 * [new tag]         3.4.2      -> 3.4.2
 * [new tag]         3.4.3      -> 3.4.3

# moving to the master branch (I already was there so this step was not necessary.)
# the message says I am up-to-date with origin/master - the master branch in my fork on the server.
# you can call "git pull" to make sure everything is up to date
C:\Users\nohwnd\Documents\GitHub\Pester [master ≡]> git checkout master
Already on 'master'
Your branch is up-to-date with 'origin/master'.

# here I am merging the offical repository master branch to my fork master branch
# you can see there were some changes to merge
C:\Users\nohwnd\Documents\GitHub\Pester [master ≡]> git merge upstream/master
Updating 6680807..dc550d2
Fast-forward
 CHANGELOG.md                       |  3 +++
 Functions/Assertions/Should.ps1    |  7 +++++++
 Functions/New-MockObject.Tests.ps1 |  7 +++++++
 Functions/New-MockObject.ps1       | 24 ++++++++++++++++++++++++
 Pester.psd1                        |  5 +++--
 Pester.psm1                        |  1 +
 README.md                          |  1 +
 7 files changed, 46 insertions(+), 2 deletions(-)
 create mode 100644 Functions/New-MockObject.Tests.ps1
 create mode 100644 Functions/New-MockObject.ps1

# pushing the merged changes to my fork on the server (origin)
C:\Users\nohwnd\Documents\GitHub\Pester [master ↑]> git push
Counting objects: 15, done.
Delta compression using up to 4 threads.
Compressing objects: 100% (15/15), done.
Writing objects: 100% (15/15), 2.23 KiB | 0 bytes/s, done.
Total 15 (delta 9), reused 0 (delta 0)
remote: Resolving deltas: 100% (9/9), completed with 7 local objects.
To https://github.com/nohwnd/Pester.git
   6680807..dc550d2  master -> master
```

### Step 3 - Create a Feature Branch

Switch to your master branch and create a new so-called feature branch from it. This branch will hold all changes for the PR you are implementing. You could put your changes directly into the master branch, but that's not recommended.

```bash
git checkout -b "FixHelpForShould"
```

This command will create a new branch based on the current branch (master) and will switch directly to it.

```powershell
C:\Users\nohwnd\Documents\GitHub\Pester [master ≡]> git checkout master
Already on 'master'
Your branch is up-to-date with 'origin/master'.
C:\Users\nohwnd\Documents\GitHub\Pester [master ≡]> git checkout -b "FixHelpForShould"
Switched to a new branch 'FixHelpForShould'
C:\Users\nohwnd\Documents\GitHub\Pester [FixHelpForShould]>
```

### Step 4 - Implement Your Changes

Now you can start implementing your changes. Make sure that your changes are relevant to the feature that you are implementing/the bug you are fixing. Avoid changing formatting and style of code that is not relevant to your changes.

### Step 5 - Commit Your Changes

Once you are done with you changes you need to commit them to your branch

### Proposing a new Function

In order to propose a new function to be added to Pester, we ask that you:

1. Fork the Pester repo.
2. Create a PS1 script with $FunctionName in the Functions directory.
3. Add your function to the FunctionsToExport key in the Pester module manifest.
4. Add the function to exported commands in the Pester module
   `& $script:SafeCommands['Export-ModuleMember'] New-Function`
5. Create a Pester test file in the form of $FunctionName.Tests.ps1 in the Functions directory.
   - Do not dot source the function script in your tests. The function will already be included as part of the module.
   - Ensure your code works on PowerShell versions 2-5.
   - Run the Pester test suite.

        ````powershell
            Get-Module Pester | Remove-Module
            Import-Module .\Pester.psd1
            Invoke-Pester -Path 'C:\Program Files\WindowsPowerShell\Modules\Pester\Functions'
        ````

6. Commit the change.
7. Submit a pull request.
