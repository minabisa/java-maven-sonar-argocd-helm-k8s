
package com.mina.cicd;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

class HelloApplicationTest {

    @Test
    void testHelloMessage() {
        HelloApplication app = new HelloApplication();

        assertEquals(
            "hello CI/CD with mina bisa",
            app.hello()
        );
    }
}
