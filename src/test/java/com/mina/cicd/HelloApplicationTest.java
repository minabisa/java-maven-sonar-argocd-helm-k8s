
package com.mina.cicd;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

class HelloApplicationTest {

    @Test
    void testHelloMessage() {
        HelloApplication app = new HelloApplication();

        assertEquals(
            "Hello from Jenkins CI/CD Pipeline - Version 2!",
            app.hello()
        );
    }
}
