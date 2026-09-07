# Cloud Computing project — Amazon Web Services

A detailed report and a presentation on a major cloud provider (AWS), covering how virtual
machines are set up, what they cost, and what they are used for — with block and data-flow
diagrams, charts built from verified data, and a reference implementation that actually runs.

## What is here

| File | What it is |
|------|-----------|
| `report.html` | **The report.** 12 sections, 9 figures, 6 tables, references. Open in any browser. |
| `slides.html` | **The presentation.** 24 slides, 16:9. Arrow keys or space to advance. |
| `data/figures.json` | Every number in both documents, with its source URL and retrieval date. |
| `terraform/main.tf` | The VM as infrastructure code (report §5.3), plus `variables.tf`, `outputs.tf`. |
| `scripts/create-ec2-cli.sh` | The same VM via the AWS CLI (report §5.2), with a tear-down path. |
| `scripts/user-data.sh` | The bootstrap script both paths use — installs nginx, serves a page naming the instance. |

Nothing needs installing, building or a network connection to read. Both HTML files are
self-contained: no CDN, no framework, no JavaScript required to read the report.

## Producing the PDF for submission

**Report:** open `report.html` → Ctrl+P → *Save as PDF*.
Set paper to **A4**, margins **Default**, and tick **Background graphics** (otherwise the
charts print without their fills). Page breaks and section headings are already set up so
each numbered section starts on a fresh page.

**Slides:** open `slides.html` → press **P** (or Ctrl+P) → *Save as PDF*.
Set orientation to **Landscape** and tick **Background graphics**. Every slide prints on its
own page as a handout.

## Running the reference implementation

Optional — the report stands on its own. This is here so the "how to set up a VM" section is
demonstrable rather than only described. It costs real money: about **$0.0084/hour**
(≈ $6.13/month) for the `t4g.micro` instance, plus a per-GB-month charge for its 20 GiB gp3
disk that continues for as long as the volume exists.

### Prerequisites

```bash
aws configure                 # an IAM user with EC2 permissions, region us-east-1
ssh-keygen -t ed25519 -f ~/.ssh/cloud-project -C cloud-project
chmod 400 ~/.ssh/cloud-project
```

### Path A — Terraform (recommended)

```bash
cd terraform
terraform init
terraform plan  -var="my_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
terraform apply -var="my_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
# outputs give you the public IP, the SSH command and the URL
```

### Path B — AWS CLI

```bash
bash scripts/create-ec2-cli.sh
```

### Tearing it down — do this

```bash
cd terraform && terraform destroy -var="my_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
# or, for path B:
bash scripts/create-ec2-cli.sh --destroy
```

**Stopping the instance is not enough.** A stopped instance stops the hourly compute charge
but its EBS volume keeps billing. Only *terminate* ends the charge. This is Figure 6 in the
report, and it is the most common way a student account runs up a bill.

## Where the numbers come from

Market-share and market-size figures were read from **Synergy Research Group's own quarterly
press releases** (six of them, May 2025 – July 2026), not from secondary articles reporting
them second-hand. Prices were read from **the AWS On-Demand pricing feed that the public EC2
pricing page itself queries** (us-east-1, Linux), retrieved 7 September 2026. Discount
ceilings come from AWS's own EC2 pricing and Savings Plans pages.

`data/figures.json` records the exact URL and retrieval date for every value. One value in the
whole report is derived rather than stated — the Q3 2025 market size — and it is labelled
*derived* everywhere it appears, with its arithmetic shown.

## A note on the Scout Hub feed

The brief asked to check <https://ai-scout-hub.anashasiba91.workers.dev/#/feed> for an existing
repository to reuse rather than reinventing one. The feed was queried
(`/api/discoveries`, 510 items: 265 YouTube, 170 GitHub, 75 Hacker News). It is an
**AI-tooling discovery stream** — LLM inference, agent harnesses, AI dev tools. It contains no
cloud-computing report template, no diagram-template repository and no AWS teaching material.
The nearest matches were `openai/tart-guest-agent` and `openai/softnet` (macOS VM tooling, not
cloud IaaS) and `microsoft/flint-chart` (a chart language). None was usable here, so nothing
was taken from it.

What *was* reused instead of reinvented: AWS's own documented reference architecture patterns,
the Terraform AWS provider's `aws_instance` resource rather than a hand-rolled API client,
SSM's public AMI parameters rather than a hard-coded image list, and a validated
colourblind-safe chart palette. No chart library was written, and none was imported — the
figures are hand-authored SVG so both documents stay self-contained and print correctly.
