import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:galini/screens/admin/admin_navbar.dart';
import 'package:galini/screens/authenticate/first_time_questionnaire_screen.dart';
import 'package:galini/screens/authenticate/role_selection_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:galini/screens/therapist/navbar_roots.dart';
import 'package:galini/widgets/navbar_roots.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool passToggle = true;
  bool isLoading = false; // to track loading state
  String email = '';
  String password = '';

  // This method shows a dialog in case of error
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text("Okay"),
          ),
        ],
      ),
    );
  }

  // Method to check if this is the first time login
  Future<void> checkFirstTimeLogin(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc['hasCompletedIntro'] == true) {
        // Navigate to the main dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const NavBarRoots(),
          ),
        );
      } else {
        // Navigate to the first-time questionnaire screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FirstTimeQuestionnaireScreen(userId: userId),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Failed to check user status. Please try again.');
      print('Error in checkFirstTimeLogin: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SingleChildScrollView(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    "images/doctors.png",
                    width: 150,
                    height: 150,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                  child: TextFormField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Enter Email",
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      email = value!;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                  child: TextFormField(
                    obscureText: passToggle,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: "Enter Password",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: InkWell(
                        onTap: () {
                          setState(() {
                            passToggle = !passToggle;
                          });
                        },
                        child: passToggle
                            ? const Icon(CupertinoIcons.eye_slash_fill)
                            : const Icon(CupertinoIcons.eye_fill),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      } else if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      password = value!;
                    },
                  ),
                ),
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: const EdgeInsets.all(15),
                        child: InkWell(
                          onTap: () async {
                              if (_formKey.currentState!.validate()) {
                                _formKey.currentState!.save();
                                setState(() {
                                  isLoading = true; // Show loading spinner
                                });

                                try {
                                  // Attempt to sign in the user using Firebase Authentication
                                  UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                                    email: email,
                                    password: password,
                                  );

                                  if (userCredential.user != null) {
                                    String userId = userCredential.user!.uid;
                                    String? role;

                                    // Check for user role in 'users' collection
                                    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                                    if (userDoc.exists) {
                                      role = userDoc['role'];
                                    }

                                    // If not found in 'users', check in 'therapists' collection with 'approved' status
                                    if (role == null) {
                                      QuerySnapshot therapistQuery = await FirebaseFirestore.instance
                                          .collection('therapist_requests')
                                          .where('uid', isEqualTo: userId)
                                          .where('status', isEqualTo: 'approved')
                                          .get();

                                      if (therapistQuery.docs.isNotEmpty) {
                                        role = therapistQuery.docs.first['role'];
                                      }
                                    }

                                    // Navigate based on role
                                    if (role != null) {
                                      if (role == 'admin') {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => const AdminNavBar()), // Admin Dashboard
                                        );
                                      } else if (role == 'therapist') {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => const NavBarRoot()), // Therapist Dashboard
                                        );
                                      } else {
                                         // Check if it's the first time login
                                        await checkFirstTimeLogin(userId);
                                        // Navigator.pushReplacement(
                                        //   context,
                                        //   MaterialPageRoute(builder: (context) => const NavBarRoots()), // Regular User Dashboard
                                        // );
                                      }
                                    } else {
                                      _showErrorDialog('User data not found.');
                                    }
                                  } else {
                                    _showErrorDialog('Login failed. Please try again.');
                                  }
                                } catch (e) {
                                  _showErrorDialog('Login failed. Please check your credentials and try again.');
                                } finally {
                                  setState(() {
                                    isLoading = false; // Hide loading indicator
                                  });
                                }
                              }
                            },

                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            width: 330,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 103, 164, 245),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                "Log In",
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RoleSelectionScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 103, 164, 245),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
