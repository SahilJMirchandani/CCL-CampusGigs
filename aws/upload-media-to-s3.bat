@echo off
REM CampusGigs - Amazon S3 Media Upload Utility
REM Uploads all avatars, gigs, attachments, banners, and health files to your AWS S3 bucket.

set BUCKET_NAME=campusgigs-sahil-779634-images
set REGION=us-east-1

echo ========================================================
echo   Uploading CampusGigs Media to Amazon S3
echo   Bucket: s3://%BUCKET_NAME%
echo   Region: %REGION%
echo ========================================================

where aws >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  echo [INFO] Found AWS CLI. Synchronizing server/uploads to S3...
  aws s3 sync ..\server\uploads\ s3://%BUCKET_NAME%/ --content-type "image/svg+xml" --exclude "system/*"
  aws s3 cp ..\server\uploads\system\status.json s3://%BUCKET_NAME%/system/status.json --content-type "application/json"
  echo.
  echo [SUCCESS] S3 sync complete! You can view your objects in the AWS S3 Console:
  echo https://us-east-1.console.aws.amazon.com/s3/buckets/%BUCKET_NAME%?region=%REGION%
) else (
  echo [INFO] AWS CLI not found on PATH. Using Node.js AWS SDK synchronizer...
  node ..\server\src\services\populate-s3-media.js
)

pause
