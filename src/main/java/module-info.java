module com.zl.pleasetweakwindows {
    requires javafx.base;
    requires transitive javafx.controls;
    requires transitive javafx.graphics;
    requires org.slf4j;
    requires ch.qos.logback.classic;
    requires ch.qos.logback.core;

    exports com.zl.pleasetweakwindows;
}