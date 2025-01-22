using Services;
using System;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers
{
    [Authorize]
    [RoutePrefix("Report")]

    public class ReportController : ApiController
    {
        private readonly ReportService report_service;        
        public ReportController(ReportService _report_service)
        {
            this.report_service = _report_service;
        }
        [HttpPost]
        [Route("GetReport")]
        public IHttpActionResult GetReport(Models.Post.Report.ReportFilter filter)
        {
            try
            {
                
                filter.StationsId.Remove(0);
                filter.ChannelsId.Remove(0);

                //var result = validator.ValidateProperties(filter);
                //if (!result.isValid)
                //{
                //    return BadRequest(result.errorMessage);
                //}
                if (filter.CompanyId == 0)
                {
                    return BadRequest("Select Parameters");
                }
                if (filter.From == null || filter.To == null)
                {
                    return BadRequest("Please Choose From and To");
                }
                if (filter.From > filter.To)
                {
                    return BadRequest("'From' date cannot be greater than 'To' date.");
                }
                var reportData = report_service.GetReport(filter);
                return Ok(reportData);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }


        [HttpGet]
        [Route("GetSelectionData")]
        public IHttpActionResult GetSelectionData()
        {
            try
            {

                var reportData = report_service.GetSelectionModel();
                return Ok(reportData);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

    }
}
