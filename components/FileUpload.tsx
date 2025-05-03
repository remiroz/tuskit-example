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

  const generateTestFile = async () => {
    // 10gb
    // const sizeInBytes = 10 * 1024 * 1024 * 1024;
    // 200mb
    const sizeInBytes = 300 * 1024 * 1024;
    // generate a stub file
    // upload the file
  
    const path = `${RNFS.DocumentDirectoryPath}/file1.txt`;
  
    const dataChunkSize = 1024;
    const chunk = "0".repeat(dataChunkSize); // Repeat '0' to make a chunk of 1KB
    const chunksToWrite = Math.ceil(sizeInBytes / dataChunkSize);
    for (let i = 0; i < chunksToWrite; i++) {
      if (i % 1000 === 0) {
        console.log(`Writing chunk ${i} of ${chunksToWrite}`);
      }
      // Here we use appendFile instead of writeFile to prevent overwriting
      await RNFS.appendFile(path, chunk, "utf8");
    }
  }

  const handleFileUpload = async () => {
    try {
      setIsUploading(true);
            
      const path = `${RNFS.DocumentDirectoryPath}/file3.txt`;
      // Upload the file
      const result = await TusKit.upload(
          path,
          'f6701f50-4efb-4d10-836e-69374c5b9b22',
          {
            filename: '1.txt',
            type: 'text',
          },
          {
              uploadURL: 'https://video.bunnycdn.com/tusupload',
              customHeaders: {
                "AuthorizationExpire": "1746242475",
                "AuthorizationSignature": "e6543ce193fedde658a1e52f48a9436c2f7e8308bb08c04489fd5fde9da59582",
                "LibraryId": "316486",
                "VideoId": "36628553-9f91-4dd6-a4cc-c78258bb0a78"
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
      try {
        await TusKit.cancelUpload('f6701f50-4efb-4d10-836e-69374c5b9a90');
        console.log('Upload cancelled');
        setUploadId(null);
        setUploadProgress(0);
      } catch (error) {
        console.error('Failed to cancel upload:', error);
      }
  };

  const getUploadDetail = async () => {
    const detail = await TusKit.getUploadTasks();
    console.log('Upload detail:', detail);
  };
  
  const getFreeStorageSpace = async () => {
    const space = await TusKit.getFreeStorageSpace();
    console.log('Free storage space:', space);
  };

  const cleanup = async () => {
    await TusKit.cleanup();
  };

  const clearAllCache = async () => {
    await TusKit.clearAllCache();
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>File Upload</Text>
      
      <View style={styles.progressContainer}>
        <Text>Upload Progress: {uploadProgress.toFixed(2)}%</Text>
      </View>

      <View style={styles.buttonContainer}>
        <Button
          title="generate test file"
          onPress={generateTestFile}
        />

        <Button
          title={isUploading ? "Uploading..." : "Upload File"}
          onPress={handleFileUpload}
          disabled={isUploading}
        />
        
        <Button
          title="Cancel Upload"
          onPress={handleCancelUpload}
        />

        <Button
          title="Get Upload Detail"
          onPress={getUploadDetail}
        />

        <Button
          title="getFreeStorageSpace"
          onPress={getFreeStorageSpace}
        />

        <Button
          title="cleanup"
          onPress={cleanup}
        />

        <Button
          title="clearAllCache"
          onPress={clearAllCache}
        />
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