import ExpoModulesCore
import TUSKit

let ON_FILE_QUEUEING_FAILED_EVENT_NAME = "onFileQueueingFailed"
let ON_FILE_QUEUEING_COMPLETED = "onFileQueueingCompleted"
let ON_PROGRESS_UPDATE_EVENT_NAME = "onProgressUpdate"
let ON_UPLOAD_COMPLETE_EVENT_NAME = "onUploadComplete"
let ON_UPLOAD_FAILED_EVENT_NAME = "onUploadFailed"

let serverURL = "https://video.bunnycdn.com/tusupload"
let sessionIdentifier = "com.balltime.tuskitupload"

// Custom errors
struct InvalidServerURLError: Error {}
struct ClientNotInitializedError: Error {}
struct InvalidFilePathError: Error {}
struct InvalidDataError: Error {}
struct InvalidUUIDError: Error {} 

public class TuskitUploadModule: Module {
  private var tusClient: TUSClient?

  private func handleStarted(fileId: String) {
    DispatchQueue.main.async {
      self.sendEvent(
        ON_FILE_QUEUEING_COMPLETED,
        [
          "fileId": fileId,
        ])
    }
  }

  private func handleProgress(progress: Float, fileId: String) {
    DispatchQueue.main.async {
      self.sendEvent(
        ON_PROGRESS_UPDATE_EVENT_NAME,
        [
          "progress": progress,
          "fileId": fileId,
        ])
    }
  }

  private func handleCompletion(fileId: String) {
    DispatchQueue.main.async {
      print("Upload complete for \(fileId)")
      self.sendEvent(
        ON_UPLOAD_COMPLETE_EVENT_NAME,
        [
        "fileId": fileId
        ])
    }
  }

  private func handleFailed(error: Error?, fileId: String) {
    DispatchQueue.main.async {
      print("Upload failed for \(fileId): \(error?.localizedDescription)")
      self.sendEvent(
        ON_UPLOAD_FAILED_EVENT_NAME,
        [
          "fileId": fileId,
          "error": error?.localizedDescription,
        ])
    }
  }

  public required init(appContext: AppContext) {
      super.init(appContext: appContext)
      if tusClient != nil {
          return
      }

      let url = URL(string: serverURL)
      let sessionConfig = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)

      guard url != nil else {
          print("Failed to create URL from serverURL: \(serverURL)")
          return
      }

      do {
          tusClient = try TUSClient(
              server: url!,
              sessionIdentifier: sessionIdentifier,
              sessionConfiguration: sessionConfig,
              storageDirectory: URL(string: "/BTTUS")!,
              chunkSize: 0
          )

          guard tusClient != nil else {
              return
          }

          tusClient!.delegate = self
      } catch {
          // Silently handle any initialization errors
      }
  }

  private func getUploadIdByVideoId(_ videoId: String) throws -> String? {
      guard let client = tusClient else {
          throw ClientNotInitializedError()
      }
      
      let uploads = try client.getStoredUploads()
      
      // Find the upload that has the matching videoId in its context
      guard let matchingUpload = uploads.first(where: { upload in
          guard let context = upload.context,
                let contextFileId = context["fileId"] else {
              return false
          }
          return contextFileId == videoId
      }) else {
          return nil
      }
      
      return matchingUpload.id.uuidString
  }

  // Each module class must implement the definition function. The definition consists of components
  // that describes the module's functionality and behavior.
  // See https://docs.expo.dev/modules/module-api for more details about available components.
  public func definition() -> ModuleDefinition {
    // Sets the name of the module that JavaScript code will use to refer to the module. Takes a string as an argument.
    // Can be inferred from module's class name, but it's recommended to set it explicitly for clarity.
    // The module will be accessible from `requireNativeModule('TuskitUpload')` in JavaScript.
    Name("TuskitUpload")

    Events(
      ON_PROGRESS_UPDATE_EVENT_NAME, ON_UPLOAD_COMPLETE_EVENT_NAME, ON_UPLOAD_FAILED_EVENT_NAME,
      ON_FILE_QUEUEING_COMPLETED, ON_FILE_QUEUEING_FAILED_EVENT_NAME)

    Function("upload") { (fileUri: URL, fileId: String, metadata: [String: String], options: [String: Any]) -> [String: Any] in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
      
        let uploadURL = (options["uploadURL"] as? String).flatMap { URL(string: $0) }
        let customHeaders = options["customHeaders"] as? [String: String] ?? [:]
        
        var metadata = metadata
        metadata["fileId"] = fileId
        
        let id = try client.uploadFileAt(
            filePath: fileUri,
            uploadURL: uploadURL,
            customHeaders: customHeaders,
            context: metadata
        )

        return ["id": id.uuidString]
    }

    Function("cancelUpload") { (fileId: String) in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        self.sendEvent(ON_PROGRESS_UPDATE_EVENT_NAME, [
          "message": "cancel"
        ])
        guard let uploadId = try self.getUploadIdByVideoId(fileId) else {
            return
        }
        guard let uuid = UUID(uuidString: uploadId) else {
            throw InvalidUUIDError()
        }
        
        try client.cancel(id: uuid)
    }

    Function("getUploadTasks") { () in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        
        let uploads = try client.getStoredUploads()
        return uploads.map { upload in
            var taskInfo: [String: Any] = [:]

            taskInfo["id"] = upload.context?["fileId"] ?? 0
            taskInfo["status"] = "Waiting"
            let upperBound = upload.uploadedRange?.upperBound ?? 0
            let total = upload.size
            taskInfo["progress"] = Float(upperBound) / Float(total)
            if(taskInfo["progress"] as! Float == 1.0) {
              taskInfo["status"] = "Completed"
            } else if(taskInfo["progress"] as! Float > 0) {
              taskInfo["status"] = "Uploading"
            } else {
              taskInfo["status"] = "Waiting"
            }

            return taskInfo
        }
    }

    Function("cleanup") { () -> Void in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        try client.cleanup()
    }

    Function("clearAllCache") { () -> Void in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        try client.clearAllCache()
    }
    
    Function("reattachEventHandlers") { () -> Void in
    }

    Function("getFreeStorageSpace") { () -> Int64 in
      do {
        let documentDirectoryURL = try FileManager.default.url(
          for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let values = try documentDirectoryURL.resourceValues(forKeys: [
          .volumeAvailableCapacityForImportantUsageKey
        ])
        if let freeSpace = values.volumeAvailableCapacityForImportantUsage {
          return freeSpace
        } else {
          print("Failed to retrieve free space.")
          return -1
        }
      } catch {
        print("Error: \(error)")
        return -1
      }
    }
  }
}

extension TuskitUploadModule: TUSClientDelegate {
    public func didStartUpload(id: UUID, context: [String: String]?, client: TUSClient) {
        if let fileId = context?["fileId"] {
            self.handleStarted(fileId: fileId)
        }
    }
    
    public func didFinishUpload(id: UUID, url: URL, context: [String: String]?, client: TUSClient) {
        if let fileId = context?["fileId"] {
            self.handleCompletion(fileId: fileId)
        }
    }
    
    public func uploadFailed(id: UUID, error: Error, context: [String: String]?, client: TUSClient) {
        if let fileId = context?["fileId"] {
            self.handleFailed(error: error, fileId: fileId)
        }
    }
    
    public func fileError(error: TUSClientError, client: TUSClient) {
    }
    
    public func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
    }
    
    public func progressFor(id: UUID, context: [String: String]?, bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
        if let fileId = context?["fileId"] {
            let progress = Float(bytesUploaded) / Float(totalBytes)
            self.handleProgress(progress: progress, fileId: fileId)
        }
    }
}