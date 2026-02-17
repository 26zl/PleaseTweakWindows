package com.zl.pleasetweakwindows;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class Tweak {
    private final String title;
    private final String applyScript;
    private final String revertScript;
    private final List<SubTweak> subTweaks;

    public Tweak(String title, String applyScript, String revertScript) {
        this.title = title;
        this.applyScript = applyScript;
        this.revertScript = revertScript;
        this.subTweaks = new ArrayList<>();
    }

    public void addSubTweak(SubTweak subTweak) {
        subTweaks.add(subTweak);
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

    public List<SubTweak> getSubTweaks() {
        return Collections.unmodifiableList(subTweaks);
    }
}