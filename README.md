# Cloud Computing project — Amazon Web Services

A technical report and an accompanying presentation on a major cloud provider, covering the
provider market, the structure of the platform, how a virtual machine is provisioned, what it
costs, and what it is used for. Includes block and data flow diagrams, charts built from
verified data, and the working configuration that builds the machine described in Section 6.

## The deliverables

| File | What it is |
|------|-----------|
| **`Cloud-Computing-AWS-Report.pdf`** | **The report.** 28 pages, A4, 13 sections, 9 figures, 10 tables, 12 references, 2 appendices. |
| **`Cloud-Computing-AWS-Slides.pdf`** | **The presentation.** 24 slides, A4 landscape. |
| `report.html`, `slides.html` | The source documents the two PDFs are typeset from. |
| `data/figures.json` | Every number in the report, each with its source address and retrieval date. |
| `terraform/main.tf` | The virtual machine as infrastructure code (report Section 6.4), with `variables.tf` and `outputs.tf`. |
| `scripts/create-ec2-cli.sh` | The same machine provisioned through the AWS CLI (Section 6.3), including the removal path. |
| `scripts/user-data.sh` | The bootstrap script both provisioning methods run on first boot. |
| `scripts/build-pdf.mjs` | Rebuilds both PDFs from the HTML sources. |

## Rebuilding the PDFs

```bash
node scripts/build-pdf.mjs           # both
node scripts/build-pdf.mjs report    # just the report
```

The script drives headless Chrome through the DevTools Protocol, which is what allows the
report to carry a running footer with page numbers while the document itself still reflows
automatically. Node 21 or later is required, because the script uses the built in WebSocket
client. There are no packages to install.

Typography: Cambria for body text at 10.5 pt, Calibri inside the figures, Consolas for code.
Page size A4 with 22 mm side margins.

## Running the reference implementation

Optional. The report stands on its own; this exists so that Section 6 is demonstrable rather
than only described. It incurs real charges: about 0.0084 US dollars per hour for the instance,
plus a per gigabyte month charge for its 20 GiB volume that continues for as long as the volume
exists.

### Prerequisites

```bash
aws configure                 # an IAM user with EC2 permissions, region us-east-1
ssh-keygen -t ed25519 -f ~/.ssh/cloud-project -C cloud-project
chmod 400 ~/.ssh/cloud-project
```

### Method A, Terraform (recommended)

```bash
cd terraform
terraform init
terraform plan  -var="my_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
terraform apply -var="my_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
```

The outputs give the public address, the SSH command and the URL.

### Method B, AWS CLI

```bash
bash scripts/create-ec2-cli.sh
```

### Removal, which should not be skipped

```bash
cd terraform && terraform destroy -var="my_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
# or, for method B:
bash scripts/create-ec2-cli.sh --destroy
```

Stopping the instance is not sufficient. A stopped instance stops the hourly compute charge but
its storage volume continues to accrue charges. Only termination ends them. This is Figure 6 in
the report and it is the most common way a small account runs up an unexpected bill.

## Where the numbers come from

Market share and market size figures were read from **Synergy Research Group's own six quarterly
press releases** covering the first quarter of 2025 to the second quarter of 2026, rather than
from secondary articles reporting them. Prices were read from **the AWS On-Demand pricing feed
that the public EC2 pricing page itself queries** for US East (N. Virginia) on Linux, retrieved
on 7 September 2026. The published maximum reductions for committed and interruptible capacity
come from the AWS pricing pages.

`data/figures.json` records the exact address and retrieval date for every value. One value in
the whole report is derived rather than stated, the market total for the third quarter of 2025,
and it is labelled as derived wherever it appears. The block storage rate is deliberately absent:
AWS serves that page from a client side template rather than a machine readable feed, so it
could not be read directly, and the report describes that charge qualitatively instead.

## A note on the Scout Hub feed

The brief asked for the feed at `ai-scout-hub.anashasiba91.workers.dev` to be checked for an
existing repository to reuse. It was queried (510 items: 265 YouTube, 170 GitHub, 75 Hacker
News). The feed is an AI tooling discovery stream and contains no cloud computing report
template, no diagram template repository and no AWS teaching material, so nothing was taken from
it. What was reused rather than rebuilt: the documented AWS reference architecture patterns, the
Terraform provider's `aws_instance` resource, the Systems Manager public AMI parameters, and a
validated colour palette for the charts. No chart library was written or imported; the figures
are hand authored SVG so that both documents remain self contained and print correctly.
