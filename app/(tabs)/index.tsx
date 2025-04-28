import { StyleSheet } from 'react-native';
import FileUpload from '@/components/FileUpload';

export default function HomeScreen() {
  return (
    <FileUpload />
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
