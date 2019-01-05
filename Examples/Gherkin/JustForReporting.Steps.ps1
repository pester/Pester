Given "step_001" {
}

When "step_002" {
}

Then "step_003" {
}

Given "step_101" {
}

Given "and_101" {
}

When "step_102" {
}

When "and_102" {
}

Then "step_103" {
    throw "An example error in the then clause"
}

Then "and_103" {
}

Given "step_201" {
}

Given "and_201" {
}

When "step_202" {
}

When "and_202" {
}

Then "step_203" {
}

Then "and_203" {
}

Given "step_301" {
}

When "step_302" {
}

Then "step_303" {
}

Then "step_304" {
    throw "Another example error in the then clause"
}

Given "step_401" {
}

When "step_402" {
    throw "An example error in the when clause"
}

Then "step_403" {
}

Given "step_701" {
    throw "An example error in the given clause"
}

When "step_702" {
}

Then "step_703" {
}
