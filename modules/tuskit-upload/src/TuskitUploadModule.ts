import { requireNativeModule } from 'expo';

const TuskitUploadModule = requireNativeModule('TuskitUpload');
export default TuskitUploadModule

export function addEventLister(eventName, listener: (event) => void): EventSubscription {
  return TuskitUploadModule.addListener(eventName, listener);
}
