# IT Support Portfolio

Three artefacts that show what I actually do by hand: a home lab with Active Directory,
a PowerShell inventory script, and a knowledge base of 20 typical first-line tickets.
Everything here is openable and checkable — not a certificate.

## Contents

| Folder | What it is | What it proves |
|---|---|---|
| `01_lab` | Diagram and write-up of a Proxmox lab: AD DS, DNS, DHCP, file server, client, Ubuntu | I understand how a domain and permissions work, and I can build and break a lab myself |
| `02_powershell` | Workstation inventory script exporting to CSV | I write working scripts, not just run other people's |
| `03_knowledge_base` | 20 instructions for typical first-line tickets | I can document a fix so a colleague can reuse it |

## 01. Lab

`01_lab/Laboratory_Proxmox.docx` and `01_lab/lab_scheme.png`.
Inside: VM list with addresses and resources, what is configured in AD, DNS, DHCP, GPO
and on the file server, the commands used to verify the stand, and four real
"broke it — found the cause — fixed it" cases.

## 02. Inventory script

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\02_powershell\Get-Inventory.ps1 -OutputPath .\inventory.csv
```

Local host is queried directly, remote hosts over a CIM session with a timeout.
An unreachable host does not abort the run: it lands in the CSV with `status = error`
and the error text. `inventory_example.csv` is sample output with sanitized data.

## 03. Knowledge base

Twenty Markdown articles plus a combined `Knowledge_Base_20_articles.docx`.
Each one: symptom, cause, steps, verification, when to escalate.

## Honest limitations

The lab runs on home hardware; it is not production. The script is verified for local
execution — remote collection needs WMI/CIM access and query permissions on the targets.
