USE [SportsDB]
GO
/****** Object:  Table [dbo].[records]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[records](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[participant_type] [varchar](100) NULL,
	[participant_id] [int] NULL,
	[record_type] [varchar](100) NULL,
	[record_label] [varchar](100) NULL,
	[record_value] [varchar](100) NULL,
	[previous_value] [varchar](100) NULL,
	[date_coverage_type] [varchar](100) NULL,
	[date_coverage_id] [int] NULL,
	[comment] [varchar](512) NULL,
 CONSTRAINT [PK__records__282DF8C2] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
