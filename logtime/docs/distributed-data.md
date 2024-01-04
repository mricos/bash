# Distributed Data Transfer System Using Rsync and SSH

## Overview
This README provides a guide for a simple system designed to transfer data from client machines to a central hub. The system leverages `rsync` for data transfer, SSH for secure communication, and a novel file naming and verification method to ensure successful data duplication. It adheres to ACID (Atomicity, Consistency, Isolation, Durability) properties to maintain data integrity and reliability.

## Table of Contents

- [System Overview](#system-overview)
- [Components](#components)
- [File Naming and Transfer Protocol](#file-naming-and-transfer-protocol)
- [Post-Transfer File Renaming Convention](#post-transfer-file-renaming-convention)
- [Verification of Transfer](#verification-of-transfer)
- [ACID Compliance](#acid-compliance)
- [Additional Considerations](#additional-considerations)

## System Overview

The system is designed to transfer data files from client machines (agents) to a central hub. Each data file's name includes the Unix timestamp of its creation, and post-transfer, the file is renamed to include the transfer completion time. This process ensures a clear record of when each file was created and transferred.

## Components

- **Client Machines (Agents)**: Where data is collected and temporarily stored.
- **Central Hub**: Server that receives, verifies, and stores transferred data.
- **Rsync**: For efficient and reliable data transfer.
- **SSH**: For secure data transmission and remote command execution.

## File Naming and Transfer Protocol

- **On Client Machines**: Data files are named using the format `data_<unix_timestamp>`, e.g., `data_1633035300`.
- **Data Transfer**: Use `rsync` over SSH to transfer data files to the hub.
- **Example Command**: `rsync -avz -e ssh /path/to/datafile user@hub:/path/to/destination`

## Post-Transfer File Renaming Convention

- **On Successful Transfer**: Rename the file on the hub to `data_<orig_timestamp>.<new_timestamp>`.
- **Automated Renaming**: Script the renaming in the post-transfer verification script.
- **Example Command**: `mv /path/to/destination/data_<orig_timestamp> /path/to/destination/data_<orig_timestamp>.<new_timestamp>`

## Verification of Transfer

- **Size Verification**: After transfer, use SSH to check the file size on the hub and compare it with the local file size.
- **Example Command**: `ssh user@hub 'stat -c%s /path/to/destination/data_<orig_timestamp>'`

## ACID Compliance

- **Atomicity**: Transactions are all-or-nothing. Use scripts to ensure either complete data transfer or none.
- **Consistency**: Maintain data integrity through checks before and after data transfer.
- **Isolation**: Handle data from different clients separately to avoid interference.
- **Durability**: Ensure permanent storage of data once written to the hub.

## Additional Considerations

- **Scalability**: The system should handle an increasing amount of data and files.
- **Security**: Implement secure SSH configurations and key management.
- **Efficiency**: Ensure the verification process does not become a bottleneck.
- **Error Handling and Logging**: Robust error handling and detailed logs are essential.

---

For detailed implementation instructions, troubleshooting, and scripts, refer to the accompanying documentation.

---
