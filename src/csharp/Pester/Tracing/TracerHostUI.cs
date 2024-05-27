// Copied from Profiler module, branch: Fix-error-autodetection, commit: 150bbcf Fix error autodetection 

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Security;

#if PESTER
namespace Pester.Tracing;
#else
namespace Profiler;
#endif

internal class TracerHostUI : PSHostUserInterface
{
    private readonly PSHostUserInterface _ui;
    private readonly Action<string> _trace;

    public TracerHostUI(PSHostUserInterface ui, Action<string> trace)
    {
        _ui = ui;
        _trace = trace;
    }

    public override PSHostRawUserInterface RawUI => _ui.RawUI;

    public override Dictionary<string, PSObject> Prompt(string caption, string message, Collection<FieldDescription> descriptions)
    {
        return _ui.Prompt(caption, message, descriptions);
    }

    public override int PromptForChoice(string caption, string message, Collection<ChoiceDescription> choices, int defaultChoice)
    {
        return _ui.PromptForChoice(caption, message, choices, defaultChoice);
    }

    public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName)
    {
        return _ui.PromptForCredential(caption, message, userName, targetName);
    }

    public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes allowedCredentialTypes, PSCredentialUIOptions options)
    {
        return _ui.PromptForCredential(caption, message, userName, targetName, allowedCredentialTypes, options);
    }

    public override string ReadLine()
    {
        return _ui.ReadLine();
    }

    public override SecureString ReadLineAsSecureString()
    {
        return _ui.ReadLineAsSecureString();
    }

    public override void Write(string value)
    {
        _ui.Write(value);
    }

    public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)
    {
        _ui.Write(foregroundColor, backgroundColor, value);
    }

    public override void WriteDebugLine(string message)
    {
        if (_trace == null)
            _ui.WriteDebugLine(message);

        _trace(message);
    }

    public override void WriteErrorLine(string value)
    {
        _ui.WriteErrorLine(value);
    }

    public override void WriteLine(string value)
    {
        _ui.WriteLine(value);
    }

    public override void WriteProgress(long sourceId, ProgressRecord record)
    {
        _ui.WriteProgress(sourceId, record);
    }

    public override void WriteVerboseLine(string message)
    {
        _ui.WriteVerboseLine(message);
    }

    public override void WriteWarningLine(string message)
    {
        _ui.WriteWarningLine(message);
    }
}
