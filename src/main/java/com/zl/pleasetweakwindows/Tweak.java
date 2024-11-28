package com.zl.pleasetweakwindows;

public class Tweak {
    private final String title;
    private final String applyScript;
    private final String revertScript;

    public Tweak(String title, String applyScript, String revertScript) {
        this.title = title;
        this.applyScript = applyScript;
        this.revertScript = revertScript;
    }

    public String getTitle() {
        return title;
    }

    public String getApplyScript() {
        return applyScript;
    }

    public String getRevertScript() {
        return revertScript;
    }
}