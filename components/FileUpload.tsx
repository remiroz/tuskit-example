import React, { useEffect, useState } from 'react';
import { View, Text, Button, StyleSheet } from 'react-native';
import * as FileSystem from 'expo-file-system';
import RNFS from "react-native-fs";
import TusKit from '../modules/tuskit-upload';
import { addEventLister } from "../modules/tuskit-upload/src/TuskitUploadModule";

addEventLister("onProgressUpdate", (update) => {
  console.log("onProgressUpdate", update);
});

export default function FileUpload() {
  const [uploadProgress, setUploadProgress] = useState<number>(0);
  const [uploadId, setUploadId] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState<boolean>(false);

  const handleFileUpload = async () => {
    try {
      setIsUploading(true);
            
      const path = `${RNFS.DocumentDirectoryPath}/file2.txt`;
      // Upload the file
      const result = await TusKit.upload(
          path,
          'f6701f50-4efb-4d10-836e-69374c5b9e90',
          {
            filename: '1.txt',
            type: 'text',
          },
          {
              uploadURL: 'https://video.bunnycdn.com/tusupload',
              customHeaders: {
                  "AuthorizationExpire": "1746093337",
                  "AuthorizationSignature": "2f2dafaf54e82e294b9fe8b54aba930830d7d745ed3f438301c5779e1280dcb3",
                  "LibraryId": "316486",
                  "VideoId": "d3fc45ad-2fde-4540-8870-5cdd3f0a950f"
              }
          }
      );

      //setUploadId(result.id);
      console.log('Upload started with ID:', result);
    } catch (error) {
      console.error('Upload failed:', error);
    } finally {
      setIsUploading(false);
    }
  };

  const handleCancelUpload = async () => {
    if (uploadId) {
      try {
        await TusKit.cancelUpload(uploadId);
        console.log('Upload cancelled');
        setUploadId(null);
        setUploadProgress(0);
      } catch (error) {
        console.error('Failed to cancel upload:', error);
      }
    }
  };

  const handleRetryUpload = async () => {
    if (uploadId) {
      try {
        const success = await TusKit.retryUpload(uploadId);
        if (success) {
          console.log('Upload retry started');
          setIsUploading(true);
        }
      } catch (error) {
        console.error('Failed to retry upload:', error);
      }
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>File Upload</Text>
      
      <View style={styles.progressContainer}>
        <Text>Upload Progress: {uploadProgress.toFixed(2)}%</Text>
      </View>

      <View style={styles.buttonContainer}>
        <Button
          title={isUploading ? "Uploading..." : "Upload File"}
          onPress={handleFileUpload}
          disabled={isUploading}
        />
        
        {uploadId && (
          <>
            <Button
              title="Cancel Upload"
              onPress={handleCancelUpload}
              disabled={!isUploading}
            />
            <Button
              title="Retry Upload"
              onPress={handleRetryUpload}
              disabled={isUploading}
            />
          </>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    justifyContent: 'center',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
  },
  progressContainer: {
    marginVertical: 20,
    alignItems: 'center',
  },
  buttonContainer: {
    gap: 10,
  },
});