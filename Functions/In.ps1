function In($path, [ScriptBlock] $execute) {
    pushd $path
    try {
        & $execute
    } finally {
        popd
    }
}
