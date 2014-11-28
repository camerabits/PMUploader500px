<html>
  <head>
    <title>500px Verification Code</title>
  </head>

  <body>
    <img src="http://www.camerabits.com/wp-content/themes/CameraBits_phase1/img/CB_logo.png" style="float: right; margin: 5px, 20px, 5px, 5px" />
    <center>
      <?php
             $code = $_GET['oauth_verifier'];
             if ($code == "") {
               echo "<h1>500px Authorisation Error</h1>";
             } else {
                 echo "<p>Enter the following 500px verification code into PhotoMechanic:</p>";
                 echo "<h1>$code</h1>";
             }
      ?>
    </center>
  </body>
</html>
