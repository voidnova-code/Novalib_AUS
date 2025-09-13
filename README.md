# Novalib_AUS
Library management system for Assam university silcher(AUS)
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>NovaLib - Library Management App</title>
<style>
  body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    margin: 0;
    padding: 2rem;
    background-color: #f8f9fa;
    color: #212529;
  }
  header {
    text-align: center;
    margin-bottom: 2rem;
  }
  h1 {
    font-size: 2.5rem;
    color: #007bff;
  }
  section {
    max-width: 900px;
    margin: 0 auto 2rem auto;
    background: white;
    padding: 2rem;
    border-radius: 8px;
    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
  }
  h2 {
    border-bottom: 2px solid #007bff;
    padding-bottom: 0.5rem;
    margin-bottom: 1rem;
    color: #0056b3;
  }
  ul {
    list-style-type: disc;
    margin-left: 1.5rem;
  }
  pre {
    background-color: #e9ecef;
    padding: 1rem;
    border-radius: 5px;
    overflow-x: auto;
  }
  a {
    color: #007bff; 
    text-decoration: none;
  }
  a:hover {
    text-decoration: underline;
  }
  footer {
    text-align: center;
    font-size: 0.9rem;
    color: #666;
    margin-top: 4rem;
  }
</style>
</head>
<body>

<header>
  <h1>NovaLib</h1>
  <p>Library Management Mobile Application</p>
</header>

<section>
  <h2>Features</h2>
  <ul>
    <li>OTP-based Authentication for secure login</li>
    <li>Barcode Scanning for books and student IDs</li>
    <li>Book Management - add, issue, and return books</li>
    <li>Student Management and registration</li>
    <li>Django REST API backend with MySQL database</li>
  </ul>
</section>

<section>
  <h2>Getting Started</h2>
  <p>Clone the repository and follow these commands to set up the backend and the Flutter app:</p>
  <pre>
git clone https://github.com/voidnova-code/Novalib_AUS.git
cd novalib
  </pre>
  <p><strong>Backend setup:</strong></p>
  <pre>
cd backend
python manage.py migrate
python manage.py runserver http://192.168.150.28:8000
  </pre>
  <p><strong>Flutter app setup:</strong></p>
  <pre>
cd novalib_testserver
flutter pub get
flutter run
  </pre>
</section>

<section>
  <h2>Technologies Used</h2>
  <ul>
    <li>Flutter & Dart</li>
    <li>Python & Django REST Framework</li>
    <li>MySQL Database</li>
    <li>Twilio SMS API</li>
    <li>Barcode Scanning Libraries</li>
  </ul>
</section>

<section>
  <h2>Contact</h2>
  <p>For questions or feedback, please contact <a href="mailto:your.email@example.com">your.email@example.com</a></p>
</section>

<footer>
  &copy; 2025 NovaLib Project
</footer>

</body>
</html>
