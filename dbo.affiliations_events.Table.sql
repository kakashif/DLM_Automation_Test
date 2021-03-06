USE [SportsDB]
GO
/****** Object:  Table [dbo].[affiliations_events]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[affiliations_events](
	[affiliation_id] [int] NOT NULL,
	[event_id] [int] NOT NULL,
 CONSTRAINT [PK_affiliations_events] PRIMARY KEY NONCLUSTERED 
(
	[affiliation_id] ASC,
	[event_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
