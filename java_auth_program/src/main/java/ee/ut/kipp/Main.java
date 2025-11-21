package ee.ut.kipp;

import com.fasterxml.jackson.databind.ObjectMapper;
import ee.ut.kipp.exceptions.InvalidRequestException;
import eu.webeid.security.authtoken.WebEidAuthToken;
import eu.webeid.security.certificate.CertificateData;
import eu.webeid.security.exceptions.CertificateNotTrustedException;
import eu.webeid.security.exceptions.JceException;
import eu.webeid.security.validator.AuthTokenValidator;
import eu.webeid.security.validator.AuthTokenValidatorBuilder;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Paths;
import java.security.cert.CertificateEncodingException;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Optional;


sealed interface Credentials permits InvalidCredentials, AuthCredentials {

    private static InvalidCredentials invalidCredentials(String error, String message) {
        return new InvalidCredentials(error, message);
    }

    static Credentials fromCertificate(X509Certificate cert) throws CertificateEncodingException {

        return CertificateData.getSubjectIdCode(cert).map(idCode -> {
                    try {
                        final Optional<String> givenName = CertificateData.getSubjectGivenName(cert);
                        final Optional<String> surname = CertificateData.getSubjectSurname(cert);

                        if (givenName.isPresent() && surname.isPresent()) {
                            return AuthCredentials.personCredentials(idCode, givenName.get(), surname.get());
                        }

                        // Organization certificates do not have given name and surname fields.
                        return CertificateData.getSubjectCN(cert)
                                .map(orgName -> AuthCredentials.organizationCredentials(idCode, orgName))
                                .orElseThrow(() -> new CertificateEncodingException("Certificate does not contain subject CN"));

                    } catch (CertificateEncodingException e) {
                        return Credentials.invalidCredentials("encoding_error", e.getMessage());
                    }
                }
        ).orElseGet(() -> Credentials.invalidCredentials("missing_id_code", "Subject ID code not found"));

    }
}

sealed interface AuthCredentials extends Credentials permits OrganizationCredentials, PersonCredentials {
    static Credentials organizationCredentials(String idCode, String name) {
        return new OrganizationCredentials(idCode, name);
    }

    static Credentials personCredentials(String idCode, String firstName, String lastName) {
        return new PersonCredentials(idCode, firstName, lastName);
    }

    String idCode();
}

public class Main {

    private static final ObjectMapper objectMapper = new ObjectMapper();

    record AuthTokenValidationRequest(String nonce, WebEidAuthToken authToken) {

        public static AuthTokenValidationRequest parseRequest(ObjectMapper mapper, String json) {
            try {
                return mapper.readValue(json, AuthTokenValidationRequest.class);
            } catch (Exception e) {
                throw new InvalidRequestException(e.getMessage());
            }
        }
    }

    public static void main(String[] args) {
        try (final var writer = new PrintWriter(System.out, true);
             final var reader = new BufferedReader(new InputStreamReader(System.in))) {
            final var config = Config.parseArgs(args);
            final AuthTokenValidator tokenValidator;
            try {
                tokenValidator = getAuthTokenValidator(config);
            } catch (NoSuchFileException e) {
                writer.println(new ErrorMap("file_not_found", e.getMessage()));
                return;
            } catch (Exception e) {
                writer.println("ERROR initializing validator: " + e.getMessage());
                e.printStackTrace(writer);
                System.exit(1);
                return;
            }

            final var json = "{\"authToken\":{\"algorithm\":\"ES384\",\"appVersion\":\"https://web-eid.eu/web-eid-app/releases/2.8.0+710\",\"format\":\"web-eid:1.0\",\"signature\":\"5zlqA1VM5NI6quDRAPF/d6zjr3Axmu9+gLEZ026e/x6QjBAylfBbpaPaIVXRkFbdqVu7ukFF18KgbQZWkBCW2XdlQfkIo0PGkQx0YP1lek4EZCKIVti7g25FkY+2lS3c\",\"unverifiedCertificate\":\"MIID4zCCA0agAwIBAgIQKmoHI1e3eVrfYtBaBzqoiTAKBggqhkjOPQQDBDBYMQswCQYDVQQGEwJFRTEbMBkGA1UECgwSU0sgSUQgU29sdXRpb25zIEFTMRcwFQYDVQRhDA5OVFJFRS0xMDc0NzAxMzETMBEGA1UEAwwKRVNURUlEMjAxODAeFw0yNDAzMDEwNzE0MTlaFw0yOTAyMjgyMTU5NTlaMGsxCzAJBgNVBAYTAkVFMSAwHgYDVQQDDBdLSVBQLEtBU1BBUiwzOTYwNjA5MDgyODENMAsGA1UEBAwES0lQUDEPMA0GA1UEKgwGS0FTUEFSMRowGAYDVQQFExFQTk9FRS0zOTYwNjA5MDgyODB2MBAGByqGSM49AgEGBSuBBAAiA2IABNTFhTlvonUA8j6E2bH41GJCX7Fkz64jos9wvLleiq1nx5Xm200ImljtTgffXqtS1DLtSE5w3JiPx2vw5IRy5IMc2DDfm6uexcC8VPWnmqoIQThfDJXO6n2ujHgYvquk76OCAcAwggG8MAkGA1UdEwQCMAAwHwYDVR0jBBgwFoAU2axw219+vpT4oOS+R6LQNK2aKhIwZgYIKwYBBQUHAQEEWjBYMC0GCCsGAQUFBzAChiFodHRwOi8vYy5zay5lZS9lc3RlaWQyMDE4LmRlci5jcnQwJwYIKwYBBQUHMAGGG2h0dHA6Ly9haWEuc2suZWUvZXN0ZWlkMjAxODAfBgNVHREEGDAWgRQzOTYwNjA5MDgyOEBlZXN0aS5lZTBHBgNVHSAEQDA+MDIGCysGAQQBg5EhAQEBMCMwIQYIKwYBBQUHAgEWFWh0dHBzOi8vd3d3LnNrLmVlL0NQUzAIBgYEAI96AQIwIAYDVR0lAQH/BBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMEMGsGCCsGAQUFBwEDBF8wXTAIBgYEAI5GAQEwUQYGBACORgEFMEcwRRY/aHR0cHM6Ly9zay5lZS9lbi9yZXBvc2l0b3J5L2NvbmRpdGlvbnMtZm9yLXVzZS1vZi1jZXJ0aWZpY2F0ZXMvEwJlbjAdBgNVHQ4EFgQUzlULqANOSfyOJjQB76adr1R14VYwDgYDVR0PAQH/BAQDAgOIMAoGCCqGSM49BAMEA4GKADCBhgJBc1XZVV/yW6g35K/96r9kJ4yPS2m4DJM1veqZfQWvUMmbKf/K5yhVthvSnMlLeD9plfa4ITJzxP4etwOa9LUSA4YCQVzsfnsnBFJj2Xe43MRBZzjEcrl9h/z9GMdk0nS8YSsZIBnWkcpXuYNAzFWaZnW4sRMmwYKNEVQaXvSKQ3k83h4Y\"},\"nonce\":\"b3kw4ZH5q1Tg7ktlajRZF0C58Qgy9hvVLyRNAfpIv08=\"}";

            String line;
            while ((line = reader.readLine()) != null) {
                try {
                    var request = AuthTokenValidationRequest.parseRequest(objectMapper, line);
                /*
                final WebEidAuthToken authToken = new WebEidAuthToken();
                authToken.setAlgorithm("ES384");
                authToken.setFormat("web-eid:1.0");
                authToken.setSignature("4E9JA0R7alDOZL3fXJ+9+C2jbbOuLDH9QXYpZrdRdvQFokpyM1Sj79ybmZ1TPaysynJqJbpIx/fNNvjZ13SRmIvIC5v5td+4o0HJuS/w4DBl0o9tx8av91fCZJkexWke");
                authToken.setUnverifiedCertificate("MIID4zCCA0agAwIBAgIQKmoHI1e3eVrfYtBaBzqoiTAKBggqhkjOPQQDBDBYMQswCQYDVQQGEwJFRTEbMBkGA1UECgwSU0sgSUQgU29sdXRpb25zIEFTMRcwFQYDVQRhDA5OVFJFRS0xMDc0NzAxMzETMBEGA1UEAwwKRVNURUlEMjAxODAeFw0yNDAzMDEwNzE0MTlaFw0yOTAyMjgyMTU5NTlaMGsxCzAJBgNVBAYTAkVFMSAwHgYDVQQDDBdLSVBQLEtBU1BBUiwzOTYwNjA5MDgyODENMAsGA1UEBAwES0lQUDEPMA0GA1UEKgwGS0FTUEFSMRowGAYDVQQFExFQTk9FRS0zOTYwNjA5MDgyODB2MBAGByqGSM49AgEGBSuBBAAiA2IABNTFhTlvonUA8j6E2bH41GJCX7Fkz64jos9wvLleiq1nx5Xm200ImljtTgffXqtS1DLtSE5w3JiPx2vw5IRy5IMc2DDfm6uexcC8VPWnmqoIQThfDJXO6n2ujHgYvquk76OCAcAwggG8MAkGA1UdEwQCMAAwHwYDVR0jBBgwFoAU2axw219+vpT4oOS+R6LQNK2aKhIwZgYIKwYBBQUHAQEEWjBYMC0GCCsGAQUFBzAChiFodHRwOi8vYy5zay5lZS9lc3RlaWQyMDE4LmRlci5jcnQwJwYIKwYBBQUHMAGGG2h0dHA6Ly9haWEuc2suZWUvZXN0ZWlkMjAxODAfBgNVHREEGDAWgRQzOTYwNjA5MDgyOEBlZXN0aS5lZTBHBgNVHSAEQDA+MDIGCysGAQQBg5EhAQEBMCMwIQYIKwYBBQUHAgEWFWh0dHBzOi8vd3d3LnNrLmVlL0NQUzAIBgYEAI96AQIwIAYDVR0lAQH/BBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMEMGsGCCsGAQUFBwEDBF8wXTAIBgYEAI5GAQEwUQYGBACORgEFMEcwRRY/aHR0cHM6Ly9zay5lZS9lbi9yZXBvc2l0b3J5L2NvbmRpdGlvbnMtZm9yLXVzZS1vZi1jZXJ0aWZpY2F0ZXMvEwJlbjAdBgNVHQ4EFgQUzlULqANOSfyOJjQB76adr1R14VYwDgYDVR0PAQH/BAQDAgOIMAoGCCqGSM49BAMEA4GKADCBhgJBc1XZVV/yW6g35K/96r9kJ4yPS2m4DJM1veqZfQWvUMmbKf/K5yhVthvSnMlLeD9plfa4ITJzxP4etwOa9LUSA4YCQVzsfnsnBFJj2Xe43MRBZzjEcrl9h/z9GMdk0nS8YSsZIBnWkcpXuYNAzFWaZnW4sRMmwYKNEVQaXvSKQ3k83h4Y");

                final String nonce = "biaWZu+GOwy59JATfbdP14NPWbyRs0BGDZyneF907/8=";

                 */

                    Credentials credentials = null;

                    try {
                        final X509Certificate certificate = tokenValidator.validate(request.authToken(), request.nonce());
                        credentials = Credentials.fromCertificate(certificate);
                    } catch (CertificateEncodingException e) {
                        System.out.println(e);
                    }

                    if (credentials != null) {
                        System.out.println(objectMapper.writeValueAsString(credentials));
                    }
                } catch (CertificateNotTrustedException e) {
                    // Most likely a mismatch in trusted certs
                    writer.println(new ErrorMap("cert_not_trusted", e.getMessage()));
                    System.exit(1);
                } catch (Exception e) {
                    // Print the initialization error to stdout for Elixir
                    writer.println("ERROR validating auth token: " + e.getMessage());
                    // Optional: print stack trace for debugging
                    e.printStackTrace(writer);
                    // Exit immediately
                    System.exit(1);
                    // just in case
                }
            }


        } catch (IOException e) {
            // TODO reader problems
            throw new RuntimeException(e);
        }
    }

    private static AuthTokenValidator getAuthTokenValidator(Config config) throws JceException, IOException, CertificateException {

        return new AuthTokenValidatorBuilder()
                .withSiteOrigin(URI.create(config.localOrigin))
                .withTrustedCertificateAuthorities(loadTrustedCACertificatesFromCerFiles(config))
                //.withTrustedCertificateAuthorities(loadTrustedCACertificatesFromTrustStore())
                .build();


    }

    public static X509Certificate[] loadTrustedCACertificatesFromCerFiles(Config config) throws IOException, CertificateException {
        final var caCertificates = new ArrayList<X509Certificate>();
        final CertificateFactory certFactory = CertificateFactory.getInstance("X.509");

        try (final var cerFilesStream = Files.newDirectoryStream(Paths.get(config.certsPath), "*.cer")) {
            for (final var path : cerFilesStream) {
                try (var is = Files.newInputStream(path)) {
                    caCertificates.add((X509Certificate) certFactory.generateCertificate(is));
                }
            }

        }

        return caCertificates.toArray(new X509Certificate[0]);
    }

    record ErrorMap(String error, String message) {
    }

    record Config(
            String certsPath,
            String trustStorePath,
            boolean digiDoc4JProd,
            String localOrigin,
            String truststorePassword) {

        /**
         * Parse command-line arguments.
         * <p>
         * Example usage:
         * java Main certsPath=certs/dev trustStorePath=trust.jks digiDoc4JProd=true localOrigin=https://localhost:4001 truststorePassword=secret
         */
        static Config parseArgs(String[] args) {
            String certsPath = "src/main/resources/certs/prod";
            String trustStorePath = null;
            boolean digiDoc4JProd = Boolean.FALSE;
            String localOrigin = "https://localhost:4001";
            String truststorePassword = null;

            for (String arg : args) {
                if (arg.startsWith("certsPath=")) {
                    certsPath = arg.substring("certsPath=".length());
                } else if (arg.startsWith("trustStorePath=")) {
                    trustStorePath = arg.substring("trustStorePath=".length());
                } else if (arg.startsWith("digiDoc4JProd=")) {
                    digiDoc4JProd = Boolean.parseBoolean(arg.substring("digiDoc4JProd=".length()));
                } else if (arg.startsWith("localOrigin=")) {
                    localOrigin = arg.substring("localOrigin=".length());
                } else if (arg.startsWith("truststorePassword=")) {
                    truststorePassword = arg.substring("truststorePassword=".length());
                }
            }

            return new Config(certsPath, trustStorePath, digiDoc4JProd, localOrigin, truststorePassword);
        }
    }
    /*

    @Bean
    public X509Certificate[] loadTrustedCACertificatesFromTrustStore() {
        List<X509Certificate> caCertificates = new ArrayList<>();

        try (InputStream is = ValidationConfiguration.class.getResourceAsStream(CERTS_RESOURCE_PATH + activeProfile + "/" + TRUSTED_CERTIFICATES_JKS)) {
            if (is == null) {
                LOG.info("Truststore file {} not found for {} profile", TRUSTED_CERTIFICATES_JKS, activeProfile);
                return new X509Certificate[0];
            }
            KeyStore keystore = KeyStore.getInstance(KeyStore.getDefaultType());
            keystore.load(is, yamlConfig().getTrustStorePassword().toCharArray());
            Enumeration<String> aliases = keystore.aliases();
            while (aliases.hasMoreElements()) {
                String alias = aliases.nextElement();
                X509Certificate certificate = (X509Certificate) keystore.getCertificate(alias);
                caCertificates.add(certificate);
            }
        } catch (IOException | CertificateException | KeyStoreException | NoSuchAlgorithmException e) {
            throw new RuntimeException("Error initializing trusted CA certificates from trust store.", e);
        }

        return caCertificates.toArray(new X509Certificate[0]);
    }

     */
}

record InvalidCredentials(String error, String message) implements Credentials {
}

record PersonCredentials(String idCode, String firstName, String lastName) implements AuthCredentials {
}

record OrganizationCredentials(String idCode, String name) implements AuthCredentials {
}
