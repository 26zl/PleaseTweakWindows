package com.zl.pleasetweakwindows;

import java.util.List;

public interface ProcessRunnerFactory {
    ProcessRunner create(List<String> command);
}
