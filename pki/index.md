---
title: Public Key Infrastructure
---
# Prerequisites

Install some stuff:

```bash 
$ sudo apt-get install -y \
    gnutls-bin \
    libengine-pkcs11-openssl
```

Export some variables to make life easier:

```bash
$ export LIBYKCS11=/usr/lib/aarch64-linux-gnu/libykcs11.so
$ export PIN=123456
$ export MGMT_KEY=010203040506070801020304050607080102030405060708
```

# Create keys on YubIkey

WARNING - this will reset all PIV data on the YubiKey!

Reset the PIV function of the YubiKey:

```bash 
$ uvx --from yubikey-manager ykman piv reset
WARNING! This will delete all stored PIV data and restore factory settings. Proceed? [y/N]: y
Resetting PIV data...
Reset complete. All PIV data has been cleared from the YubiKey.
Your YubiKey now has the default PIN, PUK and Management Key:
        PIN:    123456
        PUK:    12345678
        Management Key: 010203040506070801020304050607080102030405060708
```

Generate a key pair in slot 0 id 1:

```bash
$ pkcs11-tool \
    --module $LIBYKCS11 \
    --login \
    --login-type so \
    --pin $PIN \
    --so-pin $MGMT_KEY \
    --slot 0 \
    --id 1 \
    --key-type rsa:2048 \
    --keypairgen
Key pair generated:
Private Key Object; RSA
  label:      Private key for PIV Authentication
  ID:         01
  Usage:      decrypt, sign
  Access:     sensitive, always sensitive, never extractable, local
Public Key Object; RSA 2048 bits
  label:      Public key for PIV Authentication
  ID:         01
  Usage:      encrypt, verify
  Access:     local
```

 Generate a key pair in slot 0 id 3:

```bash 
$ pkcs11-tool \
    --module $LIBYKCS11 \
    --login \
    --login-type so \
    --pin $PIN \
    --so-pin $MGMT_KEY \
    --slot 0 \
    --id 3 \
    --key-type rsa:2048 \
    --keypairgen
Key pair generated:
Private Key Object; RSA
  label:      Private key for Key Management
  ID:         03
  Usage:      decrypt, sign
  Access:     sensitive, always sensitive, never extractable, local
Public Key Object; RSA 2048 bits
  label:      Public key for Key Management
  ID:         03
  Usage:      encrypt, verify
  Access:     local
```

List keys on the YubiKey:

```bash 
$ p11tool \
    --provider=$LIBYKCS11 \
    --set-pin=$PIN \
    --list-keys \
    --login
Object 0:
        URL: pkcs11:model=YubiKey%20YK5;manufacturer=Yubico%20%28www.yubico.com%29;serial=XXXXXXXX;token=YubiKey%20PIV%20%23XXXXXXXX;id=%01;object=Private%20key%20for%20PIV%20Authentication;type=private
        Type: Private key (RSA-2048)
        Label: Private key for PIV Authentication
        Flags: CKA_PRIVATE; CKA_NEVER_EXTRACTABLE; CKA_SENSITIVE;
        ID: 01

Object 1:
        URL: pkcs11:model=YubiKey%20YK5;manufacturer=Yubico%20%28www.yubico.com%29;serial=XXXXXXXX;token=YubiKey%20PIV%20%23XXXXXXXX;id=%03;object=Private%20key%20for%20Key%20Management;type=private
        Type: Private key (RSA-2048)
        Label: Private key for Key Management
        Flags: CKA_PRIVATE; CKA_NEVER_EXTRACTABLE; CKA_SENSITIVE;
        ID: 03

Object 2:
        URL: pkcs11:model=YubiKey%20YK5;manufacturer=Yubico%20%28www.yubico.com%29;serial=XXXXXXXX;token=YubiKey%20PIV%20%23XXXXXXXX;id=%19;object=Private%20key%20for%20PIV%20Attestation;type=private
        Type: Private key (RSA-2048)
        Label: Private key for PIV Attestation
        Flags: CKA_PRIVATE; CKA_NEVER_EXTRACTABLE; CKA_SENSITIVE;
        ID: 19
```

# Create X365 Root Certificate Authority #1

Ensure the x365-root-1/openssl.cnf file exists

Create the empty database:

```bash 
$ mkdir -p x365-root-1/certs x365-root-1/crl x365-root-1/newcerts x365-root-1/csr
$ touch x365-root-1/index.txt
$ echo 1000 > x365-root-1/serial
$ echo 1000 > x365-root-1/crlnumber
```

Create the root certificate using the key in slot 0 id 1:

```bash
$ openssl \
    req \
    -new \
    -x509 \
    -sha256 \
    -extensions v3_ca \
    -days 7300 \
    -subj "/C=AU/ST=Victoria/L=Melbourne/O=X365 Laboratories/CN=X365 Root Certificate Authority #1" \
    -config x365-root-1/openssl.cnf \
    -engine pkcs11 \
    -keyform engine \
    -key slot_0-id_01 \
    -out x365-root-1/certs/x365-root-1.crt
Engine "pkcs11" set.
```

Copy the certificate to the YubiKey:

```bash
$ pkcs11-tool \
    --module "${LIBYKCS11}" \
    --login --login-type so \
    --pin ${PIN} \
    --so-pin ${MGMT_KEY} \
    --slot 0 --id 1 \
    --write-object x365-root-1/certs/x365-root-1.crt \
    --type cert
```

# Create X365 Intermediate Certificate Authority #1

Ensure the x365-intermediate-1/openssl.cnf file exists

Create the empty database:
    
```bash 
$ mkdir -p x365-intermediate-1/certs x365-intermediate-1/crl x365-intermediate-1/newcerts x365-intermediate-1/csr
$ touch x365-intermediate-1/index.txt
$ echo 1000 > x365-intermediate-1/serial
$ echo 1000 > x365-intermediate-1/crlnumber
```

Create a CSR:

```bash
$ openssl \
    req \
    -new \
    -sha256 \
    -subj "/C=AU/ST=Victoria/L=Melbourne/O=X365 Laboratories/CN=X365 Intermediate Certificate Authority #1" \
    -config x365-intermediate-1/openssl.cnf \
    -engine pkcs11 \
    -keyform engine \
    -key slot_0-id_03 \
    -out x365-intermediate-1/csr/x365-intermediate-1.csr
Engine "pkcs11" set.
```

Sign the CSR with the root certificate:

```bash
$ openssl \
    ca \
    -batch \
    -config x365-root-1/openssl.cnf \
    -extensions v3_intermediate_ca \
    -extfile x365-intermediate-1/openssl.cnf \
    -days 3650 \
    -engine pkcs11 \
    -keyform engine \
    -keyfile slot_0-id_01 \
    -in x365-intermediate-1/csr/x365-intermediate-1.csr \
    -notext \
    -out x365-intermediate-1/certs/x365-intermediate-1.crt
```

# Create X365 User Certificate

Generate the CSR appropriately, place it in x365-intermediate-1/csr/XXX.csr.

Sign the CSR with the intermediate certificate:

```bash
$ openssl \
    ca \
    -batch \
    -config x365-intermediate-1/openssl.cnf \
    -extensions usr_cert \
    -days 3650 \
    -engine pkcs11 \
    -keyform engine \
    -keyfile slot_0-id_03 \
    -in x365-intermediate-1/csr/XXX.csr \
    -notext \
    -out x365-intermediate-1/certs/XXX.crt
```

# References

* [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/)
* [Creating a Two-Tier CA using Yubikeys](https://www.thecrosseroads.net/2022/06/creating-a-two-tier-ca-using-yubikeys/)
* [YubiKey PIV Manager](https://developers.yubico.com/yubico-piv-tool/)

