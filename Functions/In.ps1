function In($path, [ScriptBlock] $execute) {
    $old_pwd = $pwd
    pushd $path
    $pwd = $path
    try {
        & $execute
    } finally {
        popd
        $pwd = $old_pwd
    }
}
