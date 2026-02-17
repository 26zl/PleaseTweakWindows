package com.zl.pleasetweakwindows;

public class SubTweak {
    private final String name;
    private final SubTweakType type;
    private final String applyAction;
    private final String revertAction;
    private final String description;

    public enum SubTweakType {
        TOGGLE, // Apply + Revert buttons
        BUTTON  // Apply only (one-shot action)
    }

    public SubTweak(String name, SubTweakType type, String applyAction, String revertAction, String description) {
        this.name = name;
        this.type = type;
        this.applyAction = applyAction;
        this.revertAction = revertAction;
        this.description = description;
    }

    public SubTweak(String name, String applyAction, String description) {
        this(name, SubTweakType.BUTTON, applyAction, null, description);
    }

    public String getName() {
        return name;
    }

    public SubTweakType getType() {
        return type;
    }

    public String getApplyAction() {
        return applyAction;
    }

    public String getRevertAction() {
        return revertAction;
    }

    public String getDescription() {
        return description;
    }

}
