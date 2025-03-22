using Models.DisplayBoard;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IDisplayBoardService
    {
        void CreateTemplate(Template template);
        IEnumerable<Template> GetAllTemplates();
    }
}
