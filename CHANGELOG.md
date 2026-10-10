# Changelog

## Unreleased

- Accept the payload control token for direct Lambda invocations while preserving both HTTP token checks. Thanks @SebTardif (#17).

- Return client errors for malformed control API payloads instead of throwing or forwarding invalid workflow inputs, preserving omitted and null optional-field defaults.
- Abort AMI cleanup when live-instance lookup or image-list parsing fails, preserving in-use images and reporting the original error.
