USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_PageType]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_PageType](
	[ID] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[PageTypeName] [char](32) NOT NULL,
	[PageTypeDescription] [char](64) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[IsInNavigation] [bit] NOT NULL,
	[CreateDate] [datetime] NOT NULL,
 CONSTRAINT [PK_PageType] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [dbo].[USAT_PageType] ADD  CONSTRAINT [DF_Table_1_Active]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[USAT_PageType] ADD  CONSTRAINT [DF_USAT_PageType_IsInNavigation]  DEFAULT ((0)) FOR [IsInNavigation]
GO
ALTER TABLE [dbo].[USAT_PageType] ADD  CONSTRAINT [DF_PageType_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
