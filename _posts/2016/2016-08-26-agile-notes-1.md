---
layout: mindmap_4
title: Agile Notes - 1
description: What is the Agile process? What are Agile principles and values? Differences between Agile and Scrum.
categories: [English, Software, Industry]
tags: [engineering]
---

>This is still a draft, which means the content can get changes frequently until it gets done.
>This article was firstly published from <http://oliveryang.net>. The content reuse need include the original link.

* content
{:toc}

## 1. About

More and more IT companies are planning or already on the way to make the transition,
which from the traditional software development process to [Agile](https://en.wikipedia.org/wiki/Agile_software_development) process.

This article is my personal learning notes for Agile learning and practice.

## 2. What is the Agile?

Agile is just a set of **principles** and **values**, which focus on customer collaboration and iterative working software delivery by the self-organizing cross-function teams.

### 2.1 What are the Agile principles?

Agile defines **12 principles** for software development,

<pre class="km-container" minder-data-type="markdown" style="height: 500px">

- 12 Agile principles
  - Customer collaboration
    - 1. Customer satisfaction by early and continuous delivery of valuable software
    - 2. Welcome changing requirements, even in late development
  - Self-organizing cross-function teams
    - 1. Close, daily cooperation between business people and developers
    - 2. Projects are built around motivated individuals, who should be trusted
    - 3. Face-to-face conversation is the best form of communication (co-location)
    - 4. Continuous attention to technical excellence and good design
    - 5. Best architectures, requirements, and designs emerge from self-organizing teams
    - 6. Simplicity—the art of maximizing the amount of work not done—is essential
  - Working software delivery
    - 1. Working software is delivered frequently (weeks rather than months)
    - 2. Working software is the principal measure of progress
    - 3. Sustainable development, able to maintain a constant pace
    - 4. Regularly, the team reflects on how to become more effective, and adjusts accordingly

</pre>

### 2.2 What are the Agile values?

Per above principles, Agile clarifies its **values** by following **Agile manifesto**,

* Customer collaboration over contract negotiation
* Responding to change over following a plan
* Individuals and interactions over process and tools
* Working software over comprehensive documentation

### 2.3 Why Agile?

Agile is good at handling following type of uncertainties and complexities of projects,

* Business or requirements are not clear and complex.
* Technical are risky or uncertain.
* People uncertainties: distrust, conflicts, bad communications, and lack of collaborations.

## 3 What is the Scrum?

[Scrum](https://en.wikipedia.org/wiki/Scrum_(software_development)) is an **iterative** and **incremental** agile software development method。

### 3.1 Agile VS. Scrum: what is the difference?

Scrum is just one of practices/methods/frameworks of Agile.

As we mentioned before, Agile is just a set of **principles** and **value**, people have created many methods under the Agile Umbrella.
For example, [Extreme programming (XP)](https://en.wikipedia.org/wiki/Extreme_programming),
[Lean software development](https://en.wikipedia.org/wiki/Lean_software_development),
[Kanban](https://en.wikipedia.org/wiki/Kanban_(development)),
and [Scrum](https://en.wikipedia.org/wiki/Scrum_(software_development))。

### 3.2 Three Roles

There are three core roles in the Scrum framework. These core roles are ideally colocated to deliver potentially shippable Product Increments

<pre class="km-container-2" minder-data-type="markdown" style="height: 700px">
- 3 Roles
  - Product Owner
    - Position
      - One per product/team
      - SAFe has PO hierarchy 
        - Portfolio
        - Value Stream
        - Program
        - Scrum team
          - Split big backlogs at sprint level
          - Only interacts with upper level POs
    - Value
      - Accountale for winning in the market
        - Drive product success
        - Product vision
        - Own product backlog
        - Maximize ROI
        - Define value
        - Prioritize the work
        - Accept/Reject the work
        - Determine release
      - Maximizing the value of the product and of the dev team by following outcome
        - Visionary product backlogs
        - Clear sprint backlogs
    - Time Allocation
      - 50% time on external people (customer, sales & marketing, architect, stakeholder etc.)
        - Investigations, interactions & analysis
          - Customer
          - Market
          - Industry
        - Define product vision, roadmap, release plan
      - 50% time in scrum team
        - Sprint planning
        - Backlog refinement
        - Sprint review
        - Retrospective
        - Daily scrum (Optional)
    - Skills
      - Domain knowledge
        - Understand Industry
          - Vision
          - Roadmap
          - Architect
          - Features
        - Understand market
          - Market trends
          - Compitators status
        - Understand customer
          - User pain points
          - User requirements
          - User stories
      - People skills
        - Communication & Empathy & Collaboration
          - Customers
          - Marketing & Sales
          - Dev Team
          - Architect
          - Users
          - Stakeholders
      - Other soft skills
        - Decision making
        - Negotiation
        - Presentation
  - Scrum Master
    - Position
      - One per product/team
    - Value
      - Accountable for removing team impediments and empowering team to deliver the product goals
        - IS: an Agile coach
          - Facilitate team to follow Agile values, principles, and practices
          - Perceive the problems and remove team impediments
        - IS NOT: a boss
          - Different with Project Manager
          - Let dev team make the decision
    - Time allocation
      - May spend time to cooperate with people outside the team
        - Protect team to focus sprint goals
        - Help on removing external impediments
      - Major time in scrum team as Agile Coach
        - Support
          - Nurture
          - Energize
        - Educate
          - Demonstrate
          - Teach
          - Examples
        - Facilitate
          - All Scrum Meetings
          - Dialog
          - Environment
        - Feedback
          - Maintain impediments list
            - Visual & Verbal
        - Notice
          - Observe
          - Reflect
          - Question
    - Skill
      - Agile & Scrum knowledge
        - Process
        - Tools
      - Coaching skills
      - Other soft skills
        - Communication
        - Presentation
        - Collaboration
  - Dev Team
    - Position
      - 3-9 persons
      - Cross-function
        - Full cycle
        - Whole product
      - Self-organizing
        - No techincal leader & architect role
        - Use the influence rather than authority
    - Value
      - Accountable for delivering shippable PIs at the end of each Sprint
        - Practice Agile/Scrum principles & values
        - Make and meet commitments by self-organizing
        - Hands-on individual contributor
    - Time allocation
      - Avoid to cross multiple teams or have external dependencies
        - If couldn't, work with external team to define interface clearly
        - Avoid multi-tasks
      - Keep focus in sprint team
        - Only accept work from sprint backlogs
        - Focus on current sprint tasks and commitments
        - Have contributions on all sprint meetings
    - Skill
      - Technical
        - Full stack
          - End-to-end
          - Dev & QA
        - Full Dev Cycle
          - Analysis
          - Design
          - Coding
          - Test
          - Document
      - Soft Skills
        - Communication
        - Collaboration

</pre>

### 3.3 Tree Artifacts

<pre class="km-container-3" minder-data-type="markdown" style="height: 500px">
- 3 Artifacts
  - Product Backlog
  - Sprint Backlog
  - Product Increment
</pre>

### 3.4 Five Meetings

<pre class="km-container-4" minder-data-type="markdown" style="height: 500px">

- 5 Scrum Meetings
  - Sprint Planning Meeting
    - Time: Begining of sprint
    - Outcome: Task break down
    - Attendee
      - Scrum Master
        - Drive meeting
      - PO
        - Clarify user story
        - Address questions for team
      - Dev team
        - Task BreakDown
        - Task Estimation
  - Daily Scrum Meeting
  - Sprint Review Meeting
  - Sprint Retrospective Meeting
  - Project Backlog Grooming Meeting

</pre>

### 3.5 Five Values

* Focus

  Team members focus exclusively on their team goals and the Sprint Backlog; there should be no work done other than through their backlog.
* Courage

  Team members know they have the courage to work through conflict and challenges together so that they can do the right thing.
* Openness

  Team members and their stakeholders agree to be transparent about their work and any challenges they face.
* Commitment

  Team members individually commit to achieving their team goals, each and every Sprint.
* Respect

  Team members respect each other to be technically capable and to work with good intent.

## 4. References

* [Agile](https://en.wikipedia.org/wiki/Agile_software_development)
* [What is Scrum](https://en.wikipedia.org/wiki/Scrum_(software_development))
