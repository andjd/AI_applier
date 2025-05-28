
y = """
personal_info:
  name: Andrew DeFranco
  email: andrew@defran.co
  phone: (415) 205-9401
  location: Columbus, OH (Eastern Time)
  
skills:
  languages:
    - Typescript
    - Python
    - Kotlin
    - Elixir
  ai:
    - LLMs
    - RAG
  networking:
    - REST
    - GraphQL
    - gRPC
    - Websockets
    - AMQP
    - Kafka
  databases:
    - SQL
    - Elasticsearch
  cloud:
    - Systems Architecture
    - AWS
    - Serverless
    - Docker
    - Kubernetes
  web_mobile:
    - React & Redux
    - iOS + Android
  tooling:
    - Git
    - Continuous Integration
    - Agile
    - TDD
    - Claude Code

experience:
  - title: Senior Developer
    company: Kyra Health
    start_year: 2024
    end_year: null
    description: Pre-launch healthcare startup providing ICHRA benefits
    achievements:
      - Built HIPAA-compliant LLM-powered tool for health plan discovery
      - Scaled team productivity by enhancing the dev environment to support multiple independent, concurrent threads of AI code generation

  - title: Senior Developer
    company: Stealth Healthcare Startup
    start_year: 2024
    end_year: null
    description: Double-sided marketplace for in-home cosmetic treatments
    achievements:
      - Developed appointment booking application using Next.js and React

  - title: Lead Developer
    company: Enterprise Mobility
    start_year: 2023
    end_year: 2024
    description: Market-leading rental car company
    achievements:
      - Headed a 10-developer team in greenfield rebuild of mobile apps for Enterprise Rent-a-car in React Native

  - title: Senior Developer
    company: Neeva
    start_year: 2022
    end_year: 2023
    description: AI-powered startup disrupting web search
    achievements:
      - Launched a proof-of-concept mobile search experience featuring LLM summaries

  - title: Lead Developer
    company: Stationhead
    start_year: 2017
    end_year: 2022
    description: Social network connecting musicians with fandoms
    achievements:
      - Architected tipping feature
      - Planned and implemented our first microservice, creating a scalable framework and practical blueprint for breaking apart our monolith
      - Automated integrations with In-App-Purchase and payments providers
      - Leveled up our application security to harden against session jacking, spoofing, and MITM attacks with per-request cryptographically signed payloads
      - Developed database infrastructure and schema for high availability and strong consistency
      - Founded and grew the Android App team
      - Created a custom reactive state-management framework reducing bugs by 80+%
      - Oversaw outsourced team and transitioned codebase to in-house development
      - Built and deployed back-end features
      - Optimized autoscaling infrastructure hosted on AWS using Terraform
      - Architected a load-testing system to stress-test server infrastructure for stampeding herd scenarios
      - Planned schema, migrations, and ETL pipelines for SQL, Redis, and Elasticsearch databases
      - Designed and documented APIs using REST and WebSockets

  - title: Full Stack Developer
    company: Affinitiv
    start_year: 2016
    end_year: 2017
    description: CRM software for car dealerships
    achievements:
      - Updated product to a modern and responsive web app written in React and Python and hosted on AWS
      - Built secure third party integrations over HTTPS, SOAP, and AMQP
      - Modernized 25-year old SQL database while maintaining backwards compatibility
"""

_t="templates/resume_template.tex.eex"

jd="""
Rogue Fitness Is Seeking An Experienced Senior Software Engineer To Join Our Application Development Team In Columbus. As a Senior Software Engineer, You Will

Play a key role in developing software which drives the manufacturing processes at Rogue
Work closely with one or more agile teams to build and enhance our manufacturing systems using a cutting edge technical stack which includes front end development in Vue 3 and typescript with backend development in Node and .NET


The Senior Software Engineer is a fully onsite role in Columbus, Ohio. Remote work is not available.

Applicants must be authorized to work in the United States for any employer.
Responsibilities


Full Stack Development: Collaborate with one of our agile teams to design and implement scalable, and efficient full-stack solutions. Code with senior level technical capabilities including implementing well structured code and code that follows best practices
Code Review and Mentorship: Conduct thorough code reviews to maintain code quality standards. Provide mentorship and guidance to junior developers within the team. Be able to recommend performance improvements and alternative methods to deliver something to ensure the highest performance and reliability
System Architecture: Weigh in on design decisions made by our architecture team for improvements and optimizations
Collaboration: Collaborate with product owners, quality assurance and directors to deliver high-quality software solutions. The right candidate should have excellent oral and written communication


Required Qualifications

Bachelor's degree in Computer Science, Software Engineering, or related field + 5 years of software experience or Associates degree and 7 years experience
Minimum of 5 years with Javascript and/or Typescript
Minimum of 5 years with at least one major front-end technologies including one single-page web application framework such as Vue.js, React, or Angular
Minimum of 5 years with .NET or Node backend
Minimum of 5 years with database technologies such as SQL Server, T-SQL, Stored Procedures, TypeORM and/or Entity Framework
Solid understanding of object oriented design concepts, n-tier architectures, dependency injection, ORMS and relational database design
Strong problem-solving and analytical skills


Preferred Qualifications

Experience in manufacturing or warehousing
Experience with Vue 3 composition API
Experience with NestJs


By applying to Rogue, regardless of the platform you choose to use, you are agreeing to Rogue's preferred methods of communication (i.e. text message). Submitting an application, through whatever online forum is ultimately used, constitutes a knowing and voluntary agreement to send and receive text messages during the recruitment process.
"""
Dotenv.load()
Mix.Task.run("loadconfig")

{_, cover_letter} = CoverLetterGenerator.generate(y,jd)
IO.puts(cover_letter)