
import json
import os
import urllib.parse

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

aws_config = Config(
    connect_timeout=5,
    read_timeout=30,
    retries={
        "max_attempts": 3,
        "mode": "standard",
    },
)

s3 = boto3.client("s3", config=aws_config)

DESTINATION_BUCKET = os.environ["DESTINATION_BUCKET"]
DESTINATION_BUCKET_OWNER = os.environ.get("DESTINATION_BUCKET_OWNER")


def lambda_handler(event, context):
    copied = []
    errors = []
    mp4_found = 0

    records = event.get("Records", [])

    if not records:
        print("No S3 records received. Nothing to process.")
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "No files to process.",
                "copied_count": 0,
                "error_count": 0,
            }),
        }

    for record in records:
        try:
            # Ignore records that are not S3 object events.
            s3_info = record.get("s3")
            if not s3_info:
                print("Skipping record: not an S3 object event.")
                continue

            source_bucket = s3_info["bucket"]["name"]
            object_key = urllib.parse.unquote_plus(
                s3_info["object"]["key"]
            )

            # Ignore non-MP4 files without raising an exception.
            if not object_key.lower().endswith(".mp4"):
                print(f"Skipping non-MP4 file: {object_key}")
                continue

            mp4_found += 1

            # Avoid copying an object into the same bucket.
            if source_bucket == DESTINATION_BUCKET:
                print(f"Skipping destination bucket object: {object_key}")
                continue

            copy_args = {
                "Bucket": DESTINATION_BUCKET,
                "Key": object_key,
                "CopySource": {
                    "Bucket": source_bucket,
                    "Key": object_key,
                },
            }

            # Verify destination ownership only when configured.
            if DESTINATION_BUCKET_OWNER:
                copy_args["ExpectedBucketOwner"] = (
                    DESTINATION_BUCKET_OWNER
                )

            s3.copy_object(**copy_args)

            copied.append({
                "source": f"s3://{source_bucket}/{object_key}",
                "destination": (
                    f"s3://{DESTINATION_BUCKET}/{object_key}"
                ),
                "status": "success",
            })

            print(f"Successfully copied: {object_key}")

        except (ClientError, BotoCoreError, KeyError, TypeError, ValueError) as exc:
            error_message = str(exc)

            print(json.dumps({
                "message": "Failed to process S3 record.",
                "error": error_message,
            }))

            errors.append({
                "error": error_message,
            })

            # Continue processing the remaining records.
            continue

    if mp4_found == 0:
        message = "No MP4 files found in the received S3 events."
    elif errors:
        message = "Processing completed with some errors."
    else:
        message = "Processing completed successfully."

    result = {
        "message": message,
        "mp4_found": mp4_found,
        "copied_count": len(copied),
        "error_count": len(errors),
        "copied_objects": copied,
        "errors": errors,
    }

    print(json.dumps(result))

    # Return success for empty/no-MP4 events and partial copy failures.
    # This avoids retrying the entire event batch just because one
    # record failed.
    return {
        "statusCode": 200,
        "body": json.dumps(result),
    }
