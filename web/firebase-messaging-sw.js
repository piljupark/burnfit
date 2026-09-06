importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCjOVEfxJMCY5f6Qc4Hq1MWLsNfOd6m7qc",
  appId: "1:776063753690:web:b70c2ecce181739092b4e3",
  messagingSenderId: "776063753690",
  projectId: "burnfit-v01",
  authDomain: "burnfit-v01.firebaseapp.com",
  storageBucket: "burnfit-v01.firebasestorage.app",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {};
  if (title) {
    self.registration.showNotification(title, { body: body ?? "" });
  }
});
