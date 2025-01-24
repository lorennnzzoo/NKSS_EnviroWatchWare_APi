using Models;
using Post = Models.Post;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize]
    [RoutePrefix("Analyzer")]
    public class AnalyzerController : ApiController
    {
        private readonly AnalyzerService analyzer_service;
        private readonly Helpers.Validator validator = new Helpers.Validator();
        public AnalyzerController(AnalyzerService _analyzer_service)
        {
            this.analyzer_service = _analyzer_service;
        }


        [HttpGet]
        [Route("GetAnalyzer")]
        public IHttpActionResult Get(int id)
        {
            try
            {
                var analyzer = analyzer_service.GetAnalyzerById(id);
                if (analyzer == null)
                    return NotFound();
                return Ok(analyzer);
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
        [Route("GetAllAnalyzers")]
        public IHttpActionResult GetAll()
        {
            try
            {
                var analyzers = analyzer_service.GetAllAnalyzers();
                return Ok(analyzers);
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

        [HttpPost]
        [Route("AddAnalyzer")]
        public IHttpActionResult Add(Post.Analyzer analyzer)
        {
            try
            {
                //if (analyzer == null)
                //    return BadRequest("Invalid data.");
                var (isValid, errorMessage) = validator.ValidateProperties(analyzer);
                if (!isValid)
                {
                    return BadRequest(errorMessage);
                }

                analyzer_service.CreateAnalyzer(analyzer);
                return Ok();
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

        [HttpPut]
        [Route("UpdateAnalyzer")]
        public IHttpActionResult Update(Analyzer analyzer)
        {
            try
            {
                var (isValid, errorMessage) = validator.ValidateProperties(analyzer);
                if (!isValid)
                {
                    return BadRequest(errorMessage);
                }

                analyzer_service.UpdateAnalyzer(analyzer);
                return Ok();
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

        [HttpDelete]
        [Route("DeleteAnalyzer")]
        public IHttpActionResult Delete(int id)
        {
            try
            {
                analyzer_service.DeleteAnalyzer(id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }
    }
}
