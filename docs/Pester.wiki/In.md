A convenience function that executes a script from a specified path.

## Description

Before the script block passed to the execute parameter is invoked, the current location is set to the path specified. Once the script block has been executed, the location will be reset to the location the script was in prior to calling In.

## Parameters

#### `Path`

The path that the execute block will be executed in.

#### `Execute`

The script to be executed in the path provided.
