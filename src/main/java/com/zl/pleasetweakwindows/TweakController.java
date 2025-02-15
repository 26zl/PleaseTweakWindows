package com.zl.pleasetweakwindows;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

public class TweakController {
    private final List<Tweak> tweaks = new ArrayList<>();


    public void addTweak(Tweak tweak) {
        tweaks.add(tweak);
    }

    public List<Tweak> getTweaks() {
        return tweaks;
    }

    public void loadTweaks() {
        addTweak(new Tweak("All Windows Settings Optimized",
                "All windows settings optimized" + File.separator + "Windows-settings-tweaked.bat",
                "All windows settings optimized" + File.separator + "Revert.bat"));

        addTweak(new Tweak("Bcdedit Tweaks",
                "Bcdedit tweaks" + File.separator + "bcdedit-tweaks.bat",
                "Bcdedit tweaks" + File.separator + "Revert bcdedits to default.bat"));

        addTweak(new Tweak("Gaming Optimizations",
                "Gaming optimizations" + File.separator + "gaming-tweaks.bat",
                "Gaming optimizations" + File.separator + "revert gaming tweaks.bat"));

        addTweak(new Tweak("Network Optimizations",
                "Network optimizations" + File.separator + "network tweaks.bat",
                "Network optimizations" + File.separator + "revert for network tweaks.bat"));

        addTweak(new Tweak("Services Tweaks",
                "Services disable and revert" + File.separator + "Services-disabled.bat",
                "Services disable and revert" + File.separator + "Revert services to default.bat"));

        addTweak(new Tweak("UI and General Responsiveness",
                "UI and general responsiveness" + File.separator + "ui-tweaks.bat",
                "UI and general responsiveness" + File.separator + "Revert UI tweaks.bat"));


      }

    }