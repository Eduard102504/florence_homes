const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.resetPassword = functions.https.onCall(async (data, context) => {
  const email = data.email;
  const newPassword = data.newPassword;

  try {
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(user.uid, { password: newPassword });
    return { success: true, message: "Password reset successfully" };
  } catch (error) {
    console.error("Error resetting password:", error);
    return { success: false, message: error.message };
  }
});