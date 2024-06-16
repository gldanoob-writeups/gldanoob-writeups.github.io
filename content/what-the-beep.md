---
title: "IrisCTF 2024 Solution Guide - What the Beep (Forensics)"
math: true
date: 2024-01-08T00:00:00-00:00
---

CTF challenges can be intimidating for beginners, especially those without much technical background. This is a step-by-step guide to the [IrisCTF 2024](https://ctftime.org/event/2085) challenge "What the Beep", aiming to show both the thought process and the details of how I solved it, and how you can too, even without a lot of prior knowledge.

## Skills Required
- Googling
- Use of web applications
- Some algebra
- Basic Python scripting

## First Look

> **Challenge Description** \
A strange beep sound was heard across a part of the San Joaquin Valley. We have the records from some audio volume meters at various locations nearby that picked up this event. It's understood that the original sound was about 140 dB at the source, but can you find out where it originated from?

Let's download the attached file and see what it has...

"Wait, the file has a weird extension `.tar.gz`. How do I even open it?"

> ***Tip***  \
  Whenever you encounter something you've never seen before, just [look it up](https://www.cyberciti.biz/faq/how-to-create-tar-gz-file-in-linux-using-command-line/).

![Alt text](image.png)

Ok, let's see what we get inside the folder.

![Alt text](folder.png)

The names of the HTML files resemble **[GPS coordinates](https://en.wikipedia.org/wiki/Geographic_coordinate_system)**, and if we open one of them in a browser it shows a graph as follows:

![Alt text](graph.png)

As the x and y axis have units of time ($\text{s}$) and decibel ($\text{dB}$) respectively, it's reasonable to assume that the graph shows the **sound level at the corresponding time**, in which there is a peak in loudness for about 2 seconds, at around $50 \text{dB}$. That matches the "loud beep" description, and the attached audio file:

![beep](strange-sound.mp3)

Let's wrap up what information we have so far:

- A recording of a loud beep
- Four pairs of **GPS coordinates**, each with a graph of **sound level** over time

From the above, we can infer that the challenge is about **finding the location of the sound**, given the intensity of the sound recorded at different locations.

## The Approach

To clear things up, let's sketch a diagram of the situation:

> ***Tip***  \
  Diagrams are always helpful, especially when you are stuck.

![Bad drawing](image(1).png)

If we worked out $r_A$ to $r_D$, the distance between the sound source and each of the four locations, the location of the source could be easily found by **drawing four circles** around $A$ to $D$ with radii $r_A$ to $r_D$ respectively, and look for their **intersection**:

![Bad drawing 2](circles.png)

This graphical method is simple and intuitive, as it avoids solving for the coordinates of the source by hand, but it's not very accurate. However it suits our purpose as we only need to find the **approximate location** of the sound source.

## Physics Comes In Handy

Now that we only have the sound intensity, we need a way to work out the distance between the source and each location. We all know we can **judge a distance simply by the loudness of a sound**, but how do we actually *calculate* it?

That might sound familiar to you if you took high school physics, as it's the [**inverse square law**](https://en.wikipedia.org/wiki/Inverse-square_law):

$$\left(\frac{r_2}{r_1}\right)^2 = \frac{I_1}{I_2}$$

where $I_1$ is the intensity at distance $r_1$, and $r_2$ is the distance at which $I_2$ is measured. 
Note how the fraction on the right hand side is *inverted*, as it involves an inversely proportional relationship.

The equation relates the intensity of sound at two different points with their distances to the source.
In our case, $I_2$ and $r_2$ represents the intensity and distance at $A$ to $D$, and $I_1$ and $r_1$ is what we get from a known **reference point**. Where can we find such a reference point?

![hint](hint.png)

Perfect! Now just set $I_1$ to $140 \text{dB}$, and $r_1$ to $1 \ \text{ft}$... wait. That's not how it works. The **decibel scale** is **logarithmic** and **relative** to a threshold $I_0$, defined by:
    $$ n = 10 \log_{10} \left(\frac{I}{I_0}\right) $$
where $n$ is the sound intensity in $\text{dB}$.
 so we need to convert it to a linear scale first:
    $$\frac{I}{I_0} = 10^{n/10}$$

Luckily for us, we're only interested in the **ratio** of the sound intensity at different locations, so we can just ignore the $I_0$ term and work it out directly:
    $$\frac{I_1}{I_2} = \cfrac{\cfrac{I_1}{I_0}}{\cfrac{I_2}{I_0}} = \cfrac{10^{{n_1}/{10}}}{10^{{n_2}/{10}}} = 10^{(n_1 - n_2)/10} $$

> Intuitively, **an increase of $10 \text{dB}$ means multiplying the intensity by 10**. So to find out the ratio between two different intensities ${I_1}$ and ${I_2}$, we figure out *how many times we have to add $10$ to get from $n_2$ to $n_1$*, then raise $10$ to that power.

To sum up, if we were to find distance $r_A$:
    $$r_A = r_1 \sqrt{10^{(n_1 - n_A)/10}} = (1 \ \text{ft}) \cdot \sqrt{10^{(140 - n_A)/10}}$$

where $n_A$ is the intensity at $A$, measured in $\text{dB}$.

## Obtaining the Data

Now our task is to extract the exact sound level from the graphs.
But here's a small problem: we get little bumps on the curve during the 2-second beep:

![zoom](zoom.png)

**There's not only one number, but a range of numbers.** So we have to approximate the sound level instead, as accurately as possible.
The best way I can think of is to take the **average** of the data points. 

And rather than copying off the values one by one with the mouse, did you notice how the graphs are **interactive**?
The actual data must be stored *somewhere* in the HTML file, and we can **[inspect](https://firefox-source-docs.mozilla.org/devtools-user/index.html)** the page to find out where: 

![Alt text](source.png)

Note how the data is stored in the form of **[JavaScript arrays](https://developer.mozilla.org/en-US/docs/Learn/JavaScript/First_steps/Arrays)**. We can just copy the array and paste it into a text editor,
and treat it like Python lists:

```python
data_a = [49.4862687673082, 49.11758306247154, 49.35891737763439, 49.60312825002279, 49.28094240869986, 49.33179344636332, 49.77218278810612, 49.33157050295794, 49.954163292100134, 49.46399894576454, 49.75225513933776, 49.51956668498062, 49.72709095876894, 49.08380931815951, 49.80535732712877, 49.466366411374636, 49.272738443513475, 49.537197963188916, 49.42320370510891, 49.324671083447626, 49.54118211146326, 49.49531460381351, 49.976621634496894, 49.3893728063094, 49.921942150468716, 49.19386224160513, 49.36279881936855, 49.3589213415847, 49.56066713691474, 49.12186675176159, 49.98362703411643, 49.52541697547485, 49.35868710209489, 49.43923653057155, 49.98372751405347, 49.28405742162781, 49.401207574823644, 49.01614674667963, 49.13219547793331, 49.64847624718398, 49.498071028322336, 49.334549685095496, 49.458331325541025, 49.16635204000964, 49.2845016923542, 49.04043406000734, 49.911997928476055, 49.522384277676096, 49.63639242519472, 49.5321507012455, 49.580222157005686, 49.462799630990716, 49.15286264591634, 49.5636105290103, 49.24446101814839, 49.17815265294301, 49.277052087309045, 49.34785136315813, 49.2099358209713, 49.18130715442975, 49.81637365701671, 49.58976121006631, 49.26447327335997, 49.07489408373105, 49.10738248956828, 49.82935754558414, 49.7076592827515, 49.56229242462191, 49.67051905124946, 49.042312629812045, 49.561770092276326, 49.66475069029362, 49.858494354189034, 49.048272583835754, 49.9132487579282, 49.71779824360189, 49.79452312717411, 49.50065500658594, 49.84834211295007, 49.220394666568154, 49.66254149768159, 49.83640438670091, 49.10061336144564, 49.42849201280895, 49.646915124964735, 49.78950547033567, 49.4929685819846, 49.73705541695538, 49.22359955303929, 49.79862536749438, 49.652865340678765, 49.066372510572236, 49.19935726756466, 49.12145308818689, 49.438711940843866, 49.004099870912, 49.502682207162174, 49.293165246893956, 49.112557507785844, 49.544065615449895,
          49.663019552626615, 49.46132309525862, 49.28867460561771, 49.04716798758809, 49.35484951313734, 49.37733257790768, 49.84822901146003, 49.81145708386574, 49.88943707227456, 49.8760994755179, 48.99312519891967, 49.48120050185433, 49.52537947160789, 49.90610721676662, 49.914515091218576, 49.416331830579196, 49.348693840298814, 49.545231061032965, 49.114561921757456, 49.026512427769646, 49.14711681989299, 49.77105573603577, 49.536523596883534, 49.60021444492543, 49.60605081543197, 49.64891471841797, 49.4600478177719, 49.977585356380565, 49.64790786367474, 49.05339723365599, 49.776801982915465, 49.345914994020035, 49.460170041286936, 49.458597510753314, 49.404020334240904, 49.80110610568392, 49.92580226915928, 49.892740295161424, 49.32725220374159, 49.14689359709007, 49.272749076596895, 49.77397438750593, 49.092844212042216, 49.29759302412302, 49.44741729129354, 49.41099308272467, 49.079825857328835, 49.386676414641016, 49.10972967558096, 49.043040950598254, 49.11993424749808, 48.99318353627927, 49.10530939042136, 49.21146252088831, 49.15074800916907, 49.61678542581952, 49.35038069687581, 49.03078805691796, 49.6258955230806, 49.63094191644237, 49.47515877815869, 49.26668175133948, 49.31472885646965, 49.640732134272305, 49.228802255830445, 49.59159486655283, 49.06310688917667, 49.49737416549353, 49.97771220245058, 49.636406874411215, 49.173004449388536, 49.33266160439406, 49.014913705550754, 49.40246086899188, 49.329105230947825, 49.86540375321602, 49.843613528504285, 49.8657191427391, 49.219049611824765, 49.57851447868852, 49.98526126350094, 49.94445651733331, 49.45467432812931, 49.76296756625244, 49.7935233989949, 49.83262284962718, 49.93995818802516, 49.67306551801829, 49.54206148681675, 49.31504612258427, 49.94311396484975, 49.94210883611035, 49.11875893744185, 49.46127955948076, 49.7357488917027, 49.878480551044404, 49.897911048398925, 49.58542961303054, 49.59108511515634, 49.31169509848393]

```

I only extracted the numbers close to 50, since that's the relevant part of the graph. Now we can work out the distance $r_A$ in feet:

```python
import math
avg_n_a = sum(data_a) / len(data_a)
r_a = 1 * math.sqrt(10 ** ((140 - avg_n_a) / 10))
print(r_a)
```

That would give us `33573.94482372866` feet (around 10 km), which looks reasonable.

Same goes for $r_B$, $r_C$ and $r_D$. Try working them out yourself!

> ***Tip***  \
  Work the smart way, not the hard way. Perhaps let your machine do the job for you?

## Putting It All Together

Now that we have the coordinates and distances, all that's left is to draw the circles on a map... is there any convenient map application that allows us to draw circles?
![Alt text](google.png)

[There we are](https://www.mapdevelopers.com/draw-circle-tool.php) (I have no idea why this exists). Let's try to use it, pasting in the coordinates and distances...

![Alt text](map.png)

Ooh, there's an intersection! But one of the circles looks off. What went wrong?
Let's click on the circle around $A$:

![Alt text](a.png)

The coordinates shown for the circle is entirely different from what we entered (`37.185287, -120.292548`)! 
How do we manually correct it?

We see a **generated URL** for the created map, in a text box below: 

![Alt text](image-1.png)

which [contains the wrong coordinates](https://www.semrush.com/blog/url-parameters/) of the circle. 
Now let's do a little hack, replacing the numbers with the correct ones:

```
...%2C37.185287%2C-120.292548%2C...
```
and finally pasting it into the address bar:
![Alt text](correct.png)

Voila! The circles now (*nearly*) intersect at a single point. 
Pick a point best approximating the location of the sound source, and we're done! 

![Alt text](ans.png)

Where do we submit our answer? Let's look at the challenge description again:
![Alt text](desc.png)

"What's the *answer checker service*? And what about `nc what-the-beep.chal.irisc.tf 10500`?"

I'll give you a hint: `nc` is short for [**Netcat**](https://nooblinux.com/how-to-use-netcat/).

![Alt text](nc.png)

... no trick questions here, don't worry. 
Just follow the instructions and the sacred line of text you've been craving for shall reveal itself:

![Alt text](flag.png)

> ***Tip***  \
  If something is not working right, don't complain. Hack your way around it.

## TL;DR Solution
1. Extract the **average sound intensity** from the graphs, for each location
2. Use the **inverse square law** to **calculate the distance** between the sound source and each location
3. Draw **circles** on a **map** with the coordinates and distances
4. Find the **intersection** of the circles, and submit the coordinates to the answer checker

