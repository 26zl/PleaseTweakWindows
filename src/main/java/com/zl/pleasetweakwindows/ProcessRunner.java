package com.zl.pleasetweakwindows;

import java.io.IOException;
import java.util.Map;

public interface ProcessRunner {
    Process start() throws IOException;
    ProcessRunner redirectErrorStream(boolean redirectErrorStream);
    Map<String, String> environment();
}
