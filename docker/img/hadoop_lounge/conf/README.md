# Welcome to the Lounge, Chimpy

Welcome to the lounge, the node we have set up for your Hadooping pleasure


### See pig in action

```
$ pig
   # from the grunt shell
words = LOAD '/user/root/words_to_sort' AS ww:chararray; wo = ORDER words BY ww; STORE wo INTO './sorted_words';
```


### See barebones Hadoop in action

Want to convince yourself the barebones Hadoop works?

```
  # should be HADOOP_EXAMPLES_JAR=/usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar
echo $HADOOP_EXAMPLES_JAR 
  # put some dumb file up 
hadoop fs -put /etc/passwd ./count_me.txt
  # Run the 'wordcount' example
time hadoop jar $HADOOP_EXAMPLES_JAR wordcount ./count_me.txt ./count_of_words
  # See the output
hadoop fs -ls input output
hadoop fs -cat count_of_words/part\*
  # Copy it locally
hadoop fs -cat count_of_words/part\* > /tmp/count_from_hadoop.tsv
  # Run a commandline quickie that produces the same output
time cat /etc/passwd | ruby -ne 'puts $_.chomp.split' | sort | uniq -c | ruby -ne 'num, file = $_.split; puts [file,num].join("\t")' > /tmp/count_from_commandline.tsv
  # See that they did the same thing
diff -uw /tmp/count_from_* && echo "no difference"
```

```
	chimpy@worker:~$ hadoop fs -put /etc/passwd ./count_me.txt
	
	chimpy@worker:~$ time hadoop jar $HADOOP_EXAMPLES_JAR wordcount ./count_me.txt ./count_of_words
	14/11/12 20:37:37 INFO client.RMProxy: Connecting to ResourceManager at rm/172.17.3.106:8032
	...
	14/11/12 20:37:56 INFO mapreduce.Job: Job job_1415823262219_0001 completed successfully
	... job completion info
	real	0m18.163s	user	0m4.680s	sys	0m0.310s	pct	27.47
	
	chimpy@worker:~$ hadoop fs -ls input output
	-rw-r--r--   1 chimpy supergroup       1443 2014-11-12 20:37 input
	Found 2 items
	-rw-r--r--   1 chimpy supergroup          0 2014-11-12 20:37 output/_SUCCESS
	-rw-r--r--   1 chimpy supergroup       1519 2014-11-12 20:37 output/part-r-00000

	chimpy@worker:~$ hadoop fs -cat count_of_words/part\*
	(admin):/var/lib/gnats:/usr/sbin/nologin	1
	Bug-Reporting	1
	Chimpin,Docker,800-MIXALOT,:/home/chimpy:/bin/bash	1
	List	1
	Manager:/var/list:/usr/sbin/nologin	1
	System	1
	avahi:x:104:107:Avahi	1

	chimpy@worker:~$ hadoop fs -cat count_of_words/part\* > /tmp/count_from_hadoop.tsv

	chimpy@worker:~$ time cat /etc/passwd | ruby -ne 'puts $_.chomp.split' | sort | uniq -c | ruby -ne 'num, file = $_.split; puts [file,num].join("\t")' > /tmp/count_from_commandline.tsv
	real	0m0.034s	user	0m0.040s	sys	0m0.020s	pct	173.92

	chimpy@worker:~$ diff -uw /tmp/count_from_* && echo "no difference"
	no difference
```

The Hadoop version took 18 seconds, the commandline version 34 milliseconds. But the Hadoop version is **awesome**.







	
	
	(admin):/var/lib/gnats:/usr/sbin/nologin	1
	-rw-r--r--   1 chimpy supergroup          0 2014-11-12 20:37 output/_SUCCESS
	-rw-r--r--   1 chimpy supergroup       1443 2014-11-12 20:37 input
	-rw-r--r--   1 chimpy supergroup       1519 2014-11-12 20:37 output/part-r-00000
	...
	... job completion info
	14/11/12 20:37:37 INFO client.RMProxy: Connecting to ResourceManager at rm/172.17.3.106:8032
	14/11/12 20:37:56 INFO mapreduce.Job: Job job_1415823262219_0001 completed successfully
	Bug-Reporting	1
	Chimpin,Docker,800-MIXALOT,:/home/chimpy:/bin/bash	1
	Found 2 items
	List	1
	Manager:/var/list:/usr/sbin/nologin	1
	System	1
	avahi:x:104:107:Avahi	1
	no difference
	real	0m0.034s	user	0m0.040s	sys	0m0.020s	pct	173.92
	real	0m18.163s	user	0m4.680s	sys	0m0.310s	pct	27.47
