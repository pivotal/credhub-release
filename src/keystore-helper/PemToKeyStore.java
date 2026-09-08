import java.io.ByteArrayInputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.Security;
import java.security.Signature;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class PemToKeyStore {
    private static final String[] KEY_ALGORITHMS = {"RSA", "EC", "DSA", "Ed25519", "Ed448"};

    private PemToKeyStore() {}

    private static List<byte[]> readPemBlocks(Path path, String label) throws Exception {
        String pem = Files.readString(path, StandardCharsets.US_ASCII);
        Pattern pattern = Pattern.compile(
            "-----BEGIN " + Pattern.quote(label) + "-----\\s*(.*?)\\s*-----END "
                + Pattern.quote(label) + "-----",
            Pattern.DOTALL
        );
        Matcher matcher = pattern.matcher(pem);
        List<byte[]> blocks = new ArrayList<>();
        while (matcher.find()) {
            blocks.add(Base64.getMimeDecoder().decode(matcher.group(1)));
        }
        if (blocks.isEmpty()) {
            throw new IllegalArgumentException("Missing PEM block: " + label + " in " + path);
        }
        return blocks;
    }

    private static PrivateKey readPrivateKey(Path path) throws Exception {
        PKCS8EncodedKeySpec spec = new PKCS8EncodedKeySpec(readPemBlocks(path, "PRIVATE KEY").get(0));
        Exception last = null;
        for (String algorithm : KEY_ALGORITHMS) {
            try {
                return KeyFactory.getInstance(algorithm).generatePrivate(spec);
            } catch (Exception error) {
                last = error;
            }
        }
        throw new IllegalArgumentException("Unsupported PKCS#8 private key in " + path, last);
    }

    private static X509Certificate[] readCertificates(Path path) throws Exception {
        CertificateFactory factory = CertificateFactory.getInstance("X.509");
        List<byte[]> blocks = readPemBlocks(path, "CERTIFICATE");
        X509Certificate[] certificates = new X509Certificate[blocks.size()];
        for (int index = 0; index < blocks.size(); index++) {
            certificates[index] = (X509Certificate) factory.generateCertificate(
                new ByteArrayInputStream(blocks.get(index))
            );
        }
        return certificates;
    }

    private static void verifyKeyPair(PrivateKey privateKey, X509Certificate certificate) throws Exception {
        String algorithm = switch (privateKey.getAlgorithm()) {
            case "RSA" -> "SHA256withRSA";
            case "EC" -> "SHA256withECDSA";
            case "DSA" -> "SHA256withDSA";
            case "Ed25519" -> "Ed25519";
            case "Ed448" -> "Ed448";
            default -> throw new IllegalArgumentException(
                "Unsupported key algorithm: " + privateKey.getAlgorithm()
            );
        };
        byte[] message = "keystore-key-pair-check".getBytes(StandardCharsets.US_ASCII);
        Signature signer = Signature.getInstance(algorithm);
        signer.initSign(privateKey);
        signer.update(message);
        byte[] signature = signer.sign();
        signer.initVerify(certificate.getPublicKey());
        signer.update(message);
        if (!signer.verify(signature)) {
            throw new IllegalArgumentException("Private key does not match leaf certificate");
        }
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 6) {
            throw new IllegalArgumentException(
                "Usage: PemToKeyStore PRIVATE_KEY CERTIFICATES OUTPUT ALIAS PASSWORD STORE_TYPE"
            );
        }

        Path privateKeyPath = Path.of(args[0]);
        Path certificatePath = Path.of(args[1]);
        Path outputPath = Path.of(args[2]);
        String alias = args[3];
        char[] password = args[4].toCharArray();
        String storeType = args[5].toUpperCase(Locale.ROOT);
        if (!storeType.equals("JKS") && !storeType.equals("PKCS12")) {
            throw new IllegalArgumentException("STORE_TYPE must be JKS or PKCS12");
        }

        if (storeType.equals("PKCS12")) {
            Security.setProperty(
                "keystore.pkcs12.keyProtectionAlgorithm",
                "PBEWithHmacSHA256AndAES_256"
            );
            Security.setProperty("keystore.pkcs12.certProtectionAlgorithm", "NONE");
            Security.setProperty("keystore.pkcs12.macAlgorithm", "NONE");
        }

        PrivateKey privateKey = readPrivateKey(privateKeyPath);
        X509Certificate[] certificates = readCertificates(certificatePath);
        verifyKeyPair(privateKey, certificates[0]);

        KeyStore keyStore = KeyStore.getInstance(storeType);
        keyStore.load(null, password);
        keyStore.setKeyEntry(alias, privateKey, password, certificates);
        try (OutputStream output = Files.newOutputStream(outputPath)) {
            keyStore.store(output, password);
        }
    }
}
