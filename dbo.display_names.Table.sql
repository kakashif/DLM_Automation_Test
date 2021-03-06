USE [SportsDB]
GO
/****** Object:  Table [dbo].[display_names]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[display_names](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[language] [varchar](100) NOT NULL,
	[entity_type] [varchar](100) NOT NULL,
	[entity_id] [int] NOT NULL,
	[full_name] [varchar](100) NULL,
	[first_name] [varchar](100) NULL,
	[middle_name] [varchar](100) NULL,
	[last_name] [varchar](100) NULL,
	[alias] [varchar](100) NULL,
	[abbreviation] [varchar](100) NULL,
	[short_name] [varchar](100) NULL,
	[prefix] [varchar](20) NULL,
	[suffix] [varchar](20) NULL,
 CONSTRAINT [PK__display_names__5AEE82B9] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
