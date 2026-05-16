importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBEgFcxBLuk56X2yWUOJ8fQjR5nvXFDlZ4',
  appId: '1:791588998878:web:11468867eab7f646e83c4f',
  messagingSenderId: '791588998878',
  projectId: 'livaing-3ba94',
  authDomain: 'livaing-3ba94.firebaseapp.com',
  storageBucket: 'livaing-3ba94.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'Easy LivAIgn';
  const options = {
    body: notification.body || 'You have a new update.',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});
