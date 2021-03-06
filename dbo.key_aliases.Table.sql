USE [SportsDB]
GO
/****** Object:  Table [dbo].[key_aliases]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[key_aliases](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[key_id] [int] NOT NULL,
	[key_root_id] [int] NOT NULL,
 CONSTRAINT [PK__key_aliases__09A971A2] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
