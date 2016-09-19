---
layout: mindmap_4
title: Agile Notes - 1
description: What is the Agile process? What are Agile principles and values? Differences between Agile and Scrum.
categories: [English, Software, Industry]
tags: [engineering]
---

> The content reuse need include the original link: <http://oliveryang.net>

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

<pre class="km-container" minder-data-type="markdown" style="width: 100%;height: 500px">

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

There are three core roles in the Scrum Team,

* Product Owner
* Scrum Mater
* Dev Team

These core roles are ideally colocated to deliver potentially shippable Product Increments.
Below mindmap tries to show how these 3 roles deliver their work in Scrum framework.

<pre class="km-container-2" minder-data-type="markdown" style="width: 100%;height: 700px">
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
    - Work Values
      - Accountable for winning in the market by visionary product ROADMAP and PLAN
        - Drive product success
        - Product vision
        - Maximize ROI
        - Define value
        - Determine release
      - Maximizing the value of the product and of the dev team by driving clear READY and DONE
        - Clear sprint backlogs
          - Own product backlog
          - Prioritize the work
        - Clear of DoD and acceptance criteria
          - Accept/Reject the work
    - Time Application
      - 50% time on external people (customer, sales & marketing, architect, stakeholder etc.)
        - Investigations, interactions and analysis
          - Customer
          - Market
          - Industry
      - 50% time in scrum team
        - Flow management
          - Release flow management
            - Backlog grooming
            - PI/Release planning
          - Sprint flow management
            - Backlog grooming
            - Sprint planning
            - Sprint review
            - Retrospective
            - Daily scrum (Optional)
      - Output
        - Product vision
        - Product roadmap
        - Release plan
        - Product Backlog (owner)
        - Sprint Backlog (owner)
        - Product Increment (accept/reject)
    - Skill Requirements
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
    - Work Value
      - Accountable for removing team impediments and empowering team to deliver the product goals
        - IS: an Agile coach
          - Facilitate team to follow Agile values, principles, and practices
          - Perceive the problems and remove team impediments
        - IS NOT: a boss
          - Different with Project Manager
          - Let dev team make the decision
    - Time Application
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
      - Output
        - Empower team to keep dev cadence and maximize the ROI
          - AIs to remove impediments
          - AIs to run Scrum process
          - Facilate on status update (burn down chart)
        - Coach team to make the decisions to improve process
    - Skill Requirements
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
    - Work Value
      - Accountable for delivering shippable PIs at the end of each Sprint
        - Practice Agile/Scrum principles & values
        - Make and meet commitments by self-organizing
        - Hands-on individual contributor
    - Time Application
      - Avoid to cross multiple teams or have external dependencies
        - If couldn't, work with external team to define interface clearly
        - Avoid multi-tasks
      - Keep focus in sprint team
        - Only accept work from sprint backlogs
        - Focus on current sprint tasks and commitments
        - Have contributions on all sprint meetings
      - Output
        - Product Backlog (contributors)
        - Sprint Backlog (contributors)
          - Task breakdown
          - Task estimation
          - Task self-assignment
          - Status update
        - Product Increment (dev & test)
    - Skill Requirements
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

Scrum process produces 3 artifacts,

* Project Backlog
* Sprint Backlog
* Product Increment

These artifacts provide the key information about what have been planned, what are under development, and what have been done in a product.
Below mindmap organizes all major key knowledge point related these 3 artifacts.

<pre class="km-container-3" minder-data-type="markdown" style="width: 100%;height: 700px">
- 3 Artifacts
  - PB (Product Backlog)
    - Owner: Product owner
    - What
      - PB: An ordered list for things(PBIs) need to be done by Scrum team
        - Large Products: Hierarchical Backlogs
          - Need hierarchical PO
        - Multiple Teams: One Product Backlog
          - Good: Interchangeable teams with general skills
          - Bad: Different teams with special skills
        - One Team: Multiple Products
          - Try to merge to one PB to have single priority
      - [PB must be DEEP](https://www.mountaingoatsoftware.com/blog/make-the-product-backlog-deep)
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
      - PBI: whatever must be done to successfully deliver a product
        - Epic
        - Feature
          - User Story
        - Enabler
          - Defects
          - Techincal Work (POC)
          - Knowledge Acquisition (Investigation)
      - PBI: DoR (Defination of Ready)
        - User story meet INVEST criteria
          - Independent
          - Negotiable
          - Valuable
          - Estimable
          - Size appropriately
            - End-to-End: Virtual slicing
            - 1/4 sprint?
          - Testable
        - Order/Priority
          - Sortable
          - Ready for MVP(Minimum Valueable Product)
        - Business Value
          - Business value is clear enough and can be reprioritized by PO
        - Type
          - User Story
          - Enabler Story
            - Defects
            - Spike
              - Techincal Work (POC)
              - Knowledge Acquisition (Investigation)
              - Other (non-functional requirements)
                - Test automation
                - Tools for productivity
        - Description
          - 4 ways to present PBIs
            - Feature
            - User Story
              - Who: As a [Role]
              - What: I want to [Activity]
              - Why: so that [Benefit]
            - Requirements
            - Use Cases
        - Understand
          - Implementation & Task break down ready?
            - What should be done is clear enough and can be understood by team
          - Enabling spec is required?
            - [Complex PBIs need a Enabling Spec](http://www.leanagiletraining.com/key-problems/agile-specifications/)
        - Risk & Dependency
          - Free from external dependencies
        - Accept Criteria
          - Clear and easy understand
          - Be part of DoD
        - Estimate
          - Provided by team
          - No unit, which are story points
    - How
      - Global visible and maintained publicly
        - Anyone can contribute
        - PO is owner who can only make the changes
      - PBI granularity
        - From big to small
          - Epic
          - Feature
          - User story
        - Split just in time
          - Short term with more details and higher priorities
          - Long term with less details and lower priorities
          - Schedule exmaples
            - Short: 1~3 sprints
            - Medium: Next 6 months
            - Long: Future
      - PBI prioritize
        - Key factors
          - Business value: PRAISE-ED
            - Productivity gains
            - Reduced cost
            - Avoided cost
            - Increased revenue
            - Service level improvements
            - Enhanced quality
            - Ease of use
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
      - PBI changes & refine
        - Operations
          - Added
          - Deleted
          - Reprioritized
          - Estimate
            - The goal is for accuracy instread of precision
            - Must be done by dev team
              - Not PO
              - Not by a senior engineer
            - Done before PO prioritize the PBI
            - Estimates are not a commitment
            - Method: Relative estimating, instead of absolute estimating
              - Planning Poker
              - Based on points, instead of people/day
              - Find a base
          - Split
            - By data
            - By operations (CRUD)
            - By workflow steps
            - By simple/complex scenarios
            - By simpale/complex rules
            - By IO path
            - By acceptance test
            - By functional and non-functional
            - by subbing out external dependencies
            - By having spike (investigation)
          - Update for any unclear or poor definitions
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
            - Time driven: Fixed time release
              - Fixed cost
              - Scope is open
            - Feature driven: Fixed scope release
              - Fixed cost
              - Time is open
          - Extrapolate by velocity
            - Methods
              - Fixed time release
                - Remaining sprints
                - Sprint length
                - Normal velocity
                - Optimistic velocity
              - Fixed scope release
                - Total story points
                - Normal velocity
                - Optimistic velocity
            - Visualize: release burn down chart
  - SB (Sprint Backlog)
    - Owner: Dev team
    - What
      - SB: the list of work the Dev Team must address in next Sprint.
        - Pickup from top PBIs of PB to SB.
        - Until Dev team feels to reach the capacity
    - How
      - Pick up PBIs and do task break down
        - Hourly granularity
        - Big task needs a split
        - Don't exceed 8 hours
        - No pre-assignment
      - Task Estimation
        - Hourly granularity
        - Daily update remaining work
      - Dev team could change tasks of a PBI freely
      - Once SB is commited, no PBIs could be added into SB
  - PI (Product Increment)
    - What
      - PI: the sum of all the PBIs completed in a sprint
        - Meet the well-defined DoD
          - Poor DoD definition will cause,
            - Not every PI could be potentially released
            - Need extra stabilization sprint for bug fixes and testing
        - Accepted by PO per acceptance criteria on Sprint Review meeting
    - How
      - Always be potentially shippable
        - Meet the well-defined DoD
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
        - DoD has no big gaps between sprint and release level
</pre>

### 3.4 Five Meetings

A sprint iteration usually has 5 regular scrum meetings,

* Sprint Planning Meeting
* Daily Scrum Meeting
* Sprint Backlog Grooming Meeting
* Sprint Review Meeting
* Sprint Retrospective Meeting

All these meetings make sure Scrum team could follow the Agile principles and values, to maximized the value of Scrum team.
Below mindmap shows that all key information related to these 5 meeting,

<pre class="km-container-4" minder-data-type="markdown" style="width: 100%;height: 700px">

- 5 Scrum Meetings
  - Sprint Planning Meeting
    - Time
      - Begining of sprint
      - 1 time meeting
      - 2 hours per week time boxed
        - 4 hours for 4 weeks sprint
    - Attendee
      - Scrum Master
      - PO
      - Dev team
      - Others that can help on PBIs and SB deinitions
    - Outcome
      - Communication between PO and Dev team, other conversation need to be controled
      - What: Evaluate PBIs and set sprint goals with PO
        - PO clarify user stories and team need understand
        - PO need address questions for team
        - Team capacity planning
          - 6 hours per day
          - Update vacation plan
          - Update people percentage
        - Already knew team velocity
          - Per history data
          - Good guess
        - Already knew DoD scope or need update scope
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
      - How: Define Sprint Backlogs
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
      - Others as observers
    - Outcome
      - Insepct and adapt
        - Talks in front of Scrum task board
        - Only Scrum team member could talk
        - 3 questions to everyone
          - What have you done yesterday?
          - What will I do today?
            - Multiple members focus on one PBI
          - Do I see any impediment that prevents me?
        - SM: update task board per talk
          - Change Task state
            - Future
            - In progress
            - Implemented
            - Accepted (done by PO on Sprint review meeting)
          - Update task assignments
          - Add new task
          - Add impediments and see blocking tasks and stories
          - Update remaining time
          - Visualzie: sprint burn down chart
      - Peer commitment, instead of report to boss
      - Pitfalls
        - Overtime
          - Technical details discussion
          - Argument
          - No host control
        - Don't care other's talk
          - Pre-assignment task, no cooperation possibility
          - Team members are not working on one same PBI
          - Share useless information
        - Nothing can share
          - Task too big to give updates everyday
          - No preparation
  - Sprint Review Meeting
    - Time
      - End of sprint
      - 1 time meeting
      - 2 hours per two weeks time boxed
    - Attendee
      - Scrum Master
      - PO
      - Dev team
      - Customers
      - Stakeholder
      - Managers
    - Outcome
      - PO identifies what had been done and what hasn't been done
        - PO Accept/Reject work per two conditions
            - DoD
            - Accept criteria
        - Team demonstrates the work had been done and answer the questions
        - Deliverables
          - Demo for key PBIs, not just PPT
          - Working software
          - Documents
      - Build trust between PO with customers & stakeholders
        - Get feedbacks from customers & stakeholders
          - AIs for PB updates
        - PO projects likely completion date with different velocity assumptions
      - Team decisions communications
  - Sprint Retrospective Meeting
    - Time
      - End of sprint
      - 1 time meeting
      - 2 hours
    - Attendee (Internal only)
      - Scrum Master (Host)
      - PO
      - Dev team
    - Outcome
      - Review last retrospective AIs
      - Sprint retrospective and AIs generation
        - What went well
        - What could have been better
        - Things we can try for next sprint
        - Issues to escalate
      - Celeberation for team building
  - Project Backlog Grooming Meeting
    - Time
      - Per requirements after middle of sprint
      - Multiple meetings per sprint
      - 5~10% of one sprint time
    - Attendee
      - Scrum Master
      - PO
      - Dev team
      - Others that could help on PBI definitions
    - Outcome
      - Make PBIs ready for next 1~3 sprints
      - Ensure long term PBIs is under healthy status
      - PBI refinement
        - Split big PBIs
        - Added missing PBIs
        - Deleted useless PBIs
        - Reprioritize PBIs per their value
        - Do estimation (should done by dev team)
          - For accuracy instread of precision
          - Relative estimating
            - Planning Poker
            - Find a base
        - Update for any unclear or poor PBIs
          - Accept criteria update for short term PBIs
          - Other readyness update for short term PBIs
</pre>

### 3.5 Five Values

Scrum is a feedback-driven empirical approach, which needs a transparent, open and trust team culture.
Scrum defines 5 values which could ensure this culture,

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
* [Extreme programming (XP)](https://en.wikipedia.org/wiki/Extreme_programming)
* [Lean software development](https://en.wikipedia.org/wiki/Lean_software_development)
* [Kanban](https://en.wikipedia.org/wiki/Kanban_(development))
* [Scrum](https://en.wikipedia.org/wiki/Scrum_(software_development))
* [Make Product Backlog DEEP](https://www.mountaingoatsoftware.com/blog/make-the-product-backlog-deep)
* [Kano Model](https://en.wikipedia.org/wiki/Kano_model)
* [What is enabling spec](http://www.leanagiletraining.com/key-problems/agile-specifications)
* [PM Iron Triangle](https://en.wikipedia.org/wiki/Project_management_triangle)
* [How to split a user story](http://agileforall.com/resources/how-to-split-a-user-story)
