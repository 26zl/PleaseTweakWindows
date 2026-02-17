module com.zl.pleasetweakwindows {
    requires transitive javafx.controls;
    requires transitive javafx.graphics;
    requires java.net.http;
    requires org.slf4j;
    requires ch.qos.logback.classic;
    requires ch.qos.logback.core;

    exports com.zl.pleasetweakwindows;
}