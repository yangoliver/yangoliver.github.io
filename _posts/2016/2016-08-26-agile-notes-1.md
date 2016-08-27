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

There are three core roles in the Scrum Team. These core roles are ideally colocated to deliver potentially shippable Product Increments.
Below mindmap tries to show how these 3 roles deliver their work in Scrum framework.

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

<pre class="km-container-3" minder-data-type="markdown" style="height: 700px">
- 3 Artifacts
  - PB (Product Backlog)
    - What
      - PB: An ordered list for things(PBIs) need to be done by Scrum team
      - PBI: whatever must be done to successfully deliver a product
        - Features
        - Bug fixes
        - Non-functional requirements
      - [PBIs must be DEEP](https://www.mountaingoatsoftware.com/blog/make-the-product-backlog-deep)
        - Detailed appropriately
          - Much detail on higher priority PBIs
          - Less detail on low priority PBIs
        - Estimated
          - More precise on higher priority PBIs
          - Less precise on low priority PBIs
        - Emergent (Dynamic Changes)
        - Prioritized
          - High->Top
          - Low->bottom
    - How
      - Global visible and maintained publicly
        - Anyone can contribute
        - PO is owner who can only make the changes
      - 4 ways to present PBIs
        - Requirements
        - User Story
        - Feature
        - Use Cases
      - PBI granularity
        - From big to small
          - Epic
          - Feature
          - User story
            - End-to-End: Virtual slicing
            - Present with template
              - Who: As a [Role]
              - What: I want to [Activity]
              - Why: so that [Business Value]
        - Split just in time
          - Short term with more details and higher priorities
          - Long term with less details and lower priorities
          - Schedule exmaples
            - Short: 1~3 sprints
            - Medium: Next 6 months
            - Long: Future
      - PBI prioritize
        - Key factors
          - Business value: PRAISE
            - Productivity gains
            - Reduced cost
            - Avoided cost
            - Increased revenue
            - Service level improvements
            - Enhanced quality
            - Differentiation in the marketpalace
          - Efforts/Cost
          - Risk & Depedencies
          - Understand
       - Methods
         - MSCW
           - Must to have
           - Should have
           - Could be nice to have
           - Won't have this (Maybe later)
         - [Kano Model](https://en.wikipedia.org/wiki/Kano_model)
           - Basic Quality
           - Performance Quality
           - Excitement Quality
           - Indifferent Quality
           - Reverse Quality
         - Value methods
           - Theme screening
           - Theme scoring
           - Relative weighting
      - PBI readyness
        - What should be done is clear enough and can be understood by team
        - Business value is clear enough and can be reprioritized by PO
        - Complex PBI may include [Enabling Spec](http://www.leanagiletraining.com/key-problems/agile-specifications/)
        - User story meet INVEST criteria
          - Independent
          - Negotiable
          - Valuable
          - Estimable
          - Size appropriately
          - Testable
        - Free from external dependencies
      - PBI changes & refine
        - Operations
          - Added
          - Deleted
          - Reprioritized
          - Estimate (should done by dev team)
            - For accuracy instread of precision
            - Relative estimating
              - Planning Poker
              - Find a base
          - Split
          - Update
        - When refinement?
          - Backlog Grooming meetings
            - Up front meetings before 1~2 sprints
            - Workshop during sprint
          - After daily scrum
          - During sprint review
      - Meetings & activities
        - Backlog Grooming meetings
        - Sprint Planning meetings
        - Other activities
          - Business Plan
          - Brain Storming
          - Vision Statement
          - Any formal & informal communications
      - Release management
        - 5 level's Agile planning
          - Vision
          - Product roadmap
          - Replease plan
          - Sprint plan
          - Daily scrum
        - Release planning
          - [PM Iron Triangle](https://en.wikipedia.org/wiki/Project_management_triangle)
            - Cost
              - Difficult to change for software dev
            - Time
            - Scope
          - Release model
            - Fixed time release
              - Fixed cost
              - Scope is open
            - Fixed scope release
              - Fixed cost
              - Time is open
          - Extrapolate by velocity
            - Methods
              - Fixed time release
                - Remaining sprints
                - Normal velocity
                - Optimistic velocity
              - Fixed scope release
                - Total story points
                - Normal velocity
                - Optimistic velocity
            - Visualize: release burn down graph

  - SB (Sprint Backlog)
    - What
      - SB: the list of work the Dev Team must address in next Sprint.
        - Pickup from top PBIs of PB to SB.
        - Until Dev team feels to reach the capacity
    - How
      - Pick up PBIs and do task break down
        - Hourly granularity
        - Don't exceed 8 hours
        - No pre-assignment
      - Task Estimation
        - Hourly granularity
        - Big task needs a split
        - Daily update remaining work
      - Dev team could change tasks of a PBI freely
      - Once SB is commited, no PBIs could be added into SB
  - PI (Product Increment)
</pre>

### 3.4 Five Meetings

<pre class="km-container-4" minder-data-type="markdown" style="height: 700px">

- 5 Scrum Meetings
  - Sprint Planning Meeting
    - Time
      - Begining of sprint
      - 2 hours per week time boxed
        - 4 hours for 4 weeks sprint
    - Attendee
      - Scrum Master
      - PO
      - Dev team
      - Anyone could attend, but ensure conversation and work between PO and dev team
    - Outcome
      - Evaluate PBIs and set sprint goals with PO
        - PO clarify user stories and team need understand
        - PO need address questions for team
        - Team capacity planning
          - 6 hours per day
          - Update vacation plan
          - Update people percentage
        - Already knew team velocity
          - Per history data
          - Good guess
        - Already knew DOD scope or need update scope
          - Why
            - Always shipable, and avoid stabilization sprint, which is mini water-fall
            - Maintain trust with PO by not hiding undone work
          - How
            - Dev
              - Unit test
              - Code review
            - Test
              - Functional
              - Regression
              - System integration
              - Performance regression
            - Documentation
              - Design doc
              - User doc
              - Release notes
        - Pick up PBIs and add them into SB until reach capacity
      - Define Sprint Backlogs
        - Task BreakDown
          - Hourly granularity
          - Don't exceed 8 hours
          - No pre-assignment
        - High level design discussion
        - Task Estimation
          - Hourly granularity
          - Big task needs a split
        - Once SB is commited, no PBIs could be added into SB
  - Daily Scrum Meeting
    - Time
      - Every day
      - 15 min
    - Attendee
      - Scrum Master
      - Dev team
      - PO is optional
    - Outcome
      - Insepct and adapt
        - Talks per PBI order is better
        - 3 questions to everyone
          - What have you done yesterday?
          - What will I do today?
          - Do I see any impediment that prevents me?
  - Sprint Review Meeting
    - Time
      - End of sprint
      - 2 hours per week time boxed
        - 4 hours for 4 weeks sprint
    - Outcome
      - PO indentifies what had been done and what hasn't been done
      - PO Accept/Reject work per two conditions
          - DOD
          - Accept criteria
      - Team demonstrates the work had been done and answer the questions
      - PO projects likely completion date with different velocity assumptions
    - Attendee
      - Scrum Master
      - PO
      - Dev team
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
