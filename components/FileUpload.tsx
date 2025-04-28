import React, { useEffect, useState } from 'react';
import { View, Text, Button, StyleSheet } from 'react-native';
import * as FileSystem from 'expo-file-system';
import TusKit from '../modules/tuskit-upload';

export default function FileUpload() {
  const [uploadProgress, setUploadProgress] = useState<number>(0);
  const [uploadId, setUploadId] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState<boolean>(false);

  // Initialize TUS client when component mounts
  useEffect(() => {
    const initTusClient = async () => {
      try {
        await TusKit.initialize(
          'https://your-tus-server.com/files', // Your TUS server URL
          'your-app-identifier' // Unique identifier for your app
        );
        console.log('TUS client initialized successfully');
      } catch (error) {
        console.error('Failed to initialize TUS client:', error);
      }
    };

    initTusClient();

    // Set up progress listener
    const subscription = TusKit.addListener('uploadProgress', (progress) => {
      const percentage = (progress.bytesUploaded / progress.totalBytes) * 100;
      setUploadProgress(percentage);
      console.log(`Upload progress: ${percentage.toFixed(2)}%`);
    });

    // Clean up listener when component unmounts
    return () => {
      TusKit.removeListeners(1);
    };
  }, []);

  const handleFileUpload = async () => {
    try {
      setIsUploading(true);
      
      // Example: Get a file from the device
    
      // const fileUri = await FileSystem.getDocumentDirectoryAsync() + 'example.jpg';
      
      // Upload the file
      const result = await TusKit.uploadData(
          '123456789012345678901234567890',
          {
              uploadURL: 'https://video.bunnycdn.com/tusupload',
              customHeaders: {
                  "AuthorizationExpire": "1748011529",
                  "AuthorizationSignature": "7a457f743d7432721dd11b96427cfba7889fccc89fa44f65011743072ae45be7",
                  "LibraryId": "316486",
                  "VideoId": "8afae5b0-91f7-45b5-8768-ea94bb37b77b"
              },
              context: {
                  'filename': '1',
                  'type': 'image',
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