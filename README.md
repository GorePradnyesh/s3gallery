# S3 Gallery

A personal iOS app for browsing private S3 buckets — view photos, videos, PDFs, and audio files stored on AWS S3, without trusting a third-party app with your credentials.

## Features

- Browse S3 buckets and folders (list + grid views)
- View photos, videos, PDFs, and audio files inline
- Upload files and create folders
- Move, rename, and delete items
- Thumbnail caching (disk + memory) with progressive full-resolution loading
- Credentials stored exclusively in the iOS Keychain (never leaves the device)

## Requirements

- Xcode 16+
- iOS 17+ device or simulator
- An AWS account with an S3 bucket

---

## AWS Setup

### 1. Create an S3 bucket

In the [AWS Console](https://console.aws.amazon.com/s3):

1. Create a new bucket (or use an existing one).
2. Keep **Block all public access** enabled — the app uses presigned URLs, so the bucket should stay private.
3. Note the bucket's **region** (e.g. `us-east-1`).

### 2. Create an IAM user with scoped permissions

Go to **IAM → Users → Create user**. Attach a policy that grants only what the app needs. A minimal read-only policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListAllMyBuckets"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
    }
  ]
}
```

To also allow uploads, folder creation, move, and rename, add:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:CopyObject"
  ],
  "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
}
```

Replace `YOUR-BUCKET-NAME` with your actual bucket name.

### 3. Generate an access key

In the IAM user's **Security credentials** tab:

1. Click **Create access key**.
2. Choose **Other** as the use case.
3. Copy the **Access Key ID** and **Secret Access Key** — you will not be able to view the secret again.

---

## Building the App

### 1. Install dependencies

The project file is generated from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
```

### 2. Open in Xcode

```bash
open S3Gallery.xcodeproj
```

SPM will resolve the `aws-sdk-swift` package automatically. This can take several minutes on first open.

### 3. Configure signing

In Xcode, select the **S3Gallery** target → **Signing & Capabilities**:

- Set **Team** to your Apple Developer account.
- The **Bundle Identifier** defaults to `com.personal.S3Gallery` — change it if needed.

### 4. Build and run

Select a simulator or connected device and press **Cmd+R**.

On first launch, enter your **Access Key ID**, **Secret Access Key**, and **AWS Region** on the login screen. Credentials are saved to the Keychain and reused on subsequent launches.

---

## Running Tests

### Unit tests (no AWS credentials required)

Runs view model, service, and utility tests using mock S3 responses:

```bash
xcodebuild test \
  -scheme S3GalleryUnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or press **Cmd+U** in Xcode with the `S3GalleryUnitTests` scheme selected.

### Unit + UI tests

UI tests inject a `MockS3Service` via a launch argument — no real AWS account needed:

```bash
xcodebuild test \
  -scheme S3Gallery \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Integration tests (requires real AWS credentials)

Integration tests are disabled by default. To run them:

1. Remove the `.disabled` trait from `S3ServiceIntegrationTests.swift`.
2. Set the required environment variables in the scheme's **Run → Arguments** tab (or export them in your shell before calling `xcodebuild`):

```bash
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_REGION=us-east-1
export S3_TEST_BUCKET=your-bucket-name
export S3_TEST_BUCKET_WRITABLE=your-writable-bucket-name  # only needed for write tests

xcodebuild test \
  -scheme S3Gallery \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:S3GalleryIntegrationTests
```
