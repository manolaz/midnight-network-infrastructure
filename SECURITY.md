# Security Guidelines for Midnight Network Pre-Production Environment

## Section 4: Key Management Answers

### 4.1 Key Storage in a Production Cloud Environment
**Q: How would you store and protect a node operator's private keys in a production cloud environment? Walk through your recommended approach — consider HSM, KMS, secrets managers, and the tradeoffs of each.**

A: In a production cloud environment, I would use a hybrid approach relying on a cloud KMS (like AWS KMS, GCP Cloud KMS, or Azure Key Vault) in combination with a Secrets Manager for operational keys, and a dedicated Hardware Security Module (HSM) for highly sensitive signing operations if supported by the node software. 
- **Cloud KMS/Secrets Manager:** Perfect for storing the encrypted validator keystore password and automation secrets. It allows fine-grained IAM access control, automated rotation, and comprehensive audit trails (e.g., CloudTrail).
- **HSM (Hardware Security Module):** For the actual signing keys, an HSM guarantees that the private key material never leaves the hardware boundary. Cloud providers offer CloudHSM services which are highly secure but can be expensive and complex to integrate.
- **Tradeoffs:** A KMS/Secrets Manager approach is easier to integrate, cheaper, and standard practice for secrets, but the key is still loaded into memory during signing. An HSM is the gold standard for security since keys never leave the hardware, but incurs high operational and financial overhead and requires explicit support from the blockchain node software.
- **Recommendation:** Store node identity and session keys securely on the node utilizing file permissions (`chmod 600`), while using a remote Secrets Manager (like HashiCorp Vault) to securely inject passwords or key material at startup via temporary memory volumes (`tmpfs`), avoiding writing sensitive data to disk.

### 4.2 Key Rotation Policy
**Q: Describe the process you would follow to rotate a registered node key with minimal disruption to network participation. What are the risks, and how do you mitigate them?**

A: Midnight uses a Substrate-based architecture, meaning we rotate validator keys via **Session Keys**. 
1. **Generate New Keys:** Run the `author_rotateKeys` RPC call on the running node. This generates a new set of session keys within the node's local keystore and returns the public keys.
2. **Submit Extrinsic:** Construct and submit a `session.setKeys` transaction from the node's controller/stash account on the network, providing the newly generated public keys. 
3. **Wait for Epoch Transition:** The new keys will become active at the start of the next session/epoch. The node will automatically start using the new keys without requiring a restart, ensuring zero downtime.
- **Risks:** 
  - Submitting the wrong public key, leading to the node being unable to author blocks when the new session starts (resulting in slashing/offline penalties). 
  - Malicious actors calling the RPC endpoint.
- **Mitigation:** Ensure the RPC endpoint (`9944`) is bound only to `localhost` (`127.0.0.1`) or secured behind an authentication proxy. Always verify the public keys returned by the node before submitting the extrinsic.

### 4.3 Incident Response
**Q: An operator reports that they believe their signing key may have been exposed. What are your first three actions, and why?**

A: 
1. **Revoke and Rotate Immediately:** I would immediately instruct the operator to submit a transaction to change their session keys (if the controller account is safe) or chill their validator status to stop block production and prevent malicious block signing (which could lead to a severe slashing penalty).
2. **Isolate the Affected Node:** Cut off external network access to the compromised server (e.g., modify Security Group rules to block all inbound/outbound traffic except a forensic SSH IP) to prevent further exfiltration while keeping the machine state intact for investigation.
3. **Audit and Investigate:** Review access logs, SSH auth logs, and cloud audit trails (CloudTrail) to determine *how* the exposure occurred. Check for other compromised credentials or lateral movement, and migrate the node to completely new infrastructure if a host compromise is confirmed.
